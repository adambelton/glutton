class EventDelivery < ApplicationRecord
  MAX_ATTEMPTS = 10
  TERMINAL_STATUSES = %w[processed ignored skipped].freeze

  belongs_to :domain_event

  scope :completed, -> { where(status: TERMINAL_STATUSES) }
  scope :due, -> { where(status: "pending").where(next_attempt_at: ..Time.current) }

  def complete!(outcome)
    update!(status: outcome.to_s, completed_at: Time.current, last_error_class: nil)
  end

  def record_failure!(error)
    delay = [ 5 * 2**(attempts - 1), 300 ].min.seconds
    update!(status: attempts >= MAX_ATTEMPTS ? "failed" : "pending",
      next_attempt_at: Time.current + delay, last_error_class: error.class.name)
  end

  def retry!
    raise DomainEvents::RetryUnavailable, "Only failed deliveries can be retried" unless status == "failed"

    update!(status: "pending", attempts: 0, next_attempt_at: Time.current, last_error_class: nil)
  end

  def predecessor_pending?(subscription)
    earlier = DomainEvent.where(domain_event_stream_id: domain_event.domain_event_stream_id,
      name: subscription.event_names).where("sequence < ?", domain_event.sequence)
    earlier.where.not(id: EventDelivery.completed.where(subscriber:).select(:domain_event_id)).exists?
  end
end
