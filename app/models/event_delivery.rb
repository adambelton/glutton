class EventDelivery < ApplicationRecord
  MAX_ATTEMPTS = 10
  module Statuses
    PENDING = "pending".freeze
    FAILED = "failed".freeze
    PROCESSED = "processed".freeze
    IGNORED = "ignored".freeze
    SKIPPED = "skipped".freeze
  end

  belongs_to :domain_event

  scope :completed, -> { where(status: [ Statuses::PROCESSED, Statuses::IGNORED, Statuses::SKIPPED ]) }
  scope :pending, -> { where(status: Statuses::PENDING) }
  scope :failed, -> { where(status: Statuses::FAILED) }
  scope :outstanding, -> { where(status: [ Statuses::PENDING, Statuses::FAILED ]) }
  scope :due, -> { pending.where(next_attempt_at: ..Time.current) }
  scope :for_subscriber, ->(subscriber) { where(subscriber:) }
  scope :oldest_first, -> { order(:id) }
  scope :next_attempt_first, -> { order(:next_attempt_at, :id) }
  scope :ready_for, ->(subscription) {
    events = DomainEvent.for_subscription(subscription)
    completed = EventDelivery.completed.for_subscriber(subscription.name).select(:domain_event_id)
    # Exclude blocked successors before LIMIT so a failed stream cannot starve others.
    due.for_subscriber(subscription.name).where(domain_event_id: events.select(:id))
      .joins(:domain_event).where(<<~SQL, subscription.event_names)
        NOT EXISTS (
          SELECT 1 FROM domain_events earlier
          WHERE earlier.domain_event_stream_id = domain_events.domain_event_stream_id
            AND earlier.sequence < domain_events.sequence AND earlier.name IN (?)
            AND earlier.id NOT IN (#{completed.to_sql})
        )
      SQL
  }

  def complete!(outcome)
    update!(status: outcome.to_s, completed_at: Time.current, last_error_class: nil)
  end

  def record_failure!(error)
    delay = [ 5 * 2**(attempts - 1), 300 ].min.seconds
    update!(status: attempts >= MAX_ATTEMPTS ? Statuses::FAILED : Statuses::PENDING,
      next_attempt_at: Time.current + delay, last_error_class: error.class.name)
  end

  def retry!
    raise DomainEvents::RetryUnavailable, "Only failed deliveries can be retried" unless status == Statuses::FAILED

    update!(status: Statuses::PENDING, attempts: 0, next_attempt_at: Time.current, last_error_class: nil)
  end

  def predecessor_pending?(subscription)
    DomainEvent.for_subscription(subscription).preceding(domain_event).uncompleted_by(subscriber).exists?
  end
end
