module DomainEvents
  class Dispatch
    def self.call(limit: 100, subscriptions: Subscriptions.all)
      raise ArgumentError, "Batch size must be between 1 and 1000" unless (1..1000).cover?(limit)
      raise ArgumentError, "Subscriber names must be unique" unless subscriptions.map(&:name).uniq.size == subscriptions.size

      counts = Hash.new(0)
      subscriptions.each do |subscription|
        events = DomainEvent.joins(:domain_event_stream)
          .where(domain_event_streams: { publisher: subscription.publisher }, name: subscription.event_names)
        missing = events.where.not(id: EventDelivery.where(subscriber: subscription.name).select(:domain_event_id))
        missing.order(:created_at, :id).limit(limit)
          .pluck("domain_events.id", "domain_event_streams.user_id").each do |event_id, user_id|
          # The owner may be physically cleaned up between discovery and insertion.
          DomainEvent.transaction do
            user = User.lock.find_by(id: user_id)
            next unless user && DomainEvent.exists?(event_id)

            EventDelivery.create_or_find_by!(subscriber: subscription.name, domain_event_id: event_id) do |delivery|
              delivery.next_attempt_at = Time.current
            end
          end
        end

        due = EventDelivery.due.where(subscriber: subscription.name, domain_event_id: events.select(:id))
          .joins(:domain_event)
        # Filter blocked successors before LIMIT so one failed stream cannot starve others.
        due = due.where(<<~SQL, subscription.event_names, subscription.name, EventDelivery::Statuses::TERMINAL)
          NOT EXISTS (
            SELECT 1 FROM domain_events earlier
            WHERE earlier.domain_event_stream_id = domain_events.domain_event_stream_id
              AND earlier.sequence < domain_events.sequence AND earlier.name IN (?)
              AND NOT EXISTS (
                SELECT 1 FROM event_deliveries receipt
                WHERE receipt.domain_event_id = earlier.id AND receipt.subscriber = ?
                  AND receipt.status IN (?)
              )
          )
        SQL
        due.order(:next_attempt_at, :id).limit(limit).pluck(:id).each do |id|
          counts[Deliver.call(delivery_id: id, subscription:)] += 1
        end
      end
      counts
    end
  end
end
