class DomainEvent < ApplicationRecord
  belongs_to :domain_event_stream

  scope :for_subscription, ->(subscription) {
    joins(:domain_event_stream)
      .where(domain_event_streams: { publisher: subscription.publisher }, name: subscription.event_names)
  }
  scope :undiscovered_by, ->(subscriber) {
    where.not(id: EventDelivery.for_subscriber(subscriber).select(:domain_event_id))
  }
  scope :uncompleted_by, ->(subscriber) {
    where.not(id: EventDelivery.for_subscriber(subscriber).completed.select(:domain_event_id))
  }
  scope :preceding, ->(event) {
    where(domain_event_stream_id: event.domain_event_stream_id).where("domain_events.sequence < ?", event.sequence)
  }
  scope :oldest_first, -> { order(:created_at, :id) }

  def readonly?
    persisted?
  end
end
