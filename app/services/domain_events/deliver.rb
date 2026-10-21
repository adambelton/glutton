module DomainEvents
  class Deliver
    def self.call(delivery_id:, subscription:)
      delivery = EventDelivery.for_subscriber(subscription.name).find_by(id: delivery_id)
      return :missing unless delivery

      user_id = delivery.domain_event.domain_event_stream.user_id
      User.transaction do
        user = User.lock.find_by(id: user_id)
        delivery = EventDelivery.for_subscriber(subscription.name).lock.find_by(id: delivery_id)
        return :missing unless delivery
        return :not_due unless delivery.status == EventDelivery::Statuses::PENDING && delivery.next_attempt_at <= Time.current
        return :blocked if delivery.predecessor_pending?(subscription)

        unless user&.active?
          delivery.complete!(:skipped)
          return :skipped
        end

        delivery.increment!(:attempts)
        begin
          EventDelivery.transaction(requires_new: true) do
            outcome = subscription.handler.call(event: delivery.domain_event, user:)
            raise ArgumentError, "Handler must return processed or ignored" unless [ :processed, :ignored ].include?(outcome)

            delivery.complete!(outcome)
            outcome
          rescue ActiveRecord::Rollback
            raise ArgumentError, "Handler rolled back without a delivery outcome"
          end
        rescue StandardError => error
          delivery.reload.record_failure!(error)
          delivery.status == EventDelivery::Statuses::FAILED ? :failed : :retrying
        end
      end
    end
  end
end
