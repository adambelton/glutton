module DomainEvents
  class Dispatch
    def self.call(limit: 100, subscriptions: Subscriptions.all)
      raise ArgumentError, "Batch size must be between 1 and 1000" unless (1..1000).cover?(limit)
      raise ArgumentError, "Subscriber names must be unique" unless subscriptions.map(&:name).uniq.size == subscriptions.size

      counts = Hash.new(0)
      subscriptions.each do |subscription|
        missing = DomainEvent.for_subscription(subscription).undiscovered_by(subscription.name)
        missing.oldest_first.limit(limit)
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

        EventDelivery.ready_for(subscription).next_attempt_first.limit(limit).pluck(:id).each do |id|
          counts[Deliver.call(delivery_id: id, subscription:)] += 1
        end
      end
      counts
    end
  end
end
