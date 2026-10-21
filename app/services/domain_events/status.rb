module DomainEvents
  class Status
    def self.call(subscriptions: Subscriptions.all)
      oldest = EventDelivery.outstanding.minimum(:created_at)
      {
        retained_events: DomainEvent.count,
        undiscovered: subscriptions.map do |subscription|
          events = DomainEvent.joins(:domain_event_stream)
            .where(domain_event_streams: { publisher: subscription.publisher }, name: subscription.event_names)
            .where.not(id: EventDelivery.where(subscriber: subscription.name).select(:domain_event_id))
          first = events.minimum(:created_at)
          { subscriber: subscription.name, count: events.count,
            oldest_age_seconds: first ? (Time.current - first).to_i : nil }
        end,
        deliveries: EventDelivery.group(:subscriber, :status).count.map { |(subscriber, status), count| { subscriber:, status:, count: } },
        oldest_outstanding_age_seconds: oldest ? (Time.current - oldest).to_i : nil,
        failed: EventDelivery.where(status: EventDelivery::Statuses::FAILED).order(:id).limit(100).pluck(:id, :subscriber, :last_error_class)
      }
    end
  end
end
