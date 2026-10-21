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
  scope :failed, -> { where(status: Statuses::FAILED) }
  scope :outstanding, -> { where(status: [ Statuses::PENDING, Statuses::FAILED ]) }
  scope :due, -> { where(status: Statuses::PENDING).where(next_attempt_at: ..Time.current) }

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
    earlier = DomainEvent.where(domain_event_stream_id: domain_event.domain_event_stream_id,
      name: subscription.event_names).where("sequence < ?", domain_event.sequence)
    earlier.where.not(id: EventDelivery.completed.where(subscriber:).select(:domain_event_id)).exists?
  end
end
