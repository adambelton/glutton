module DomainEvents
  module Delivery
    class Deliver
      def self.call(delivery_id:, subscription:)
        delivery = EventDelivery.find_by(id: delivery_id, subscriber: subscription.name)
        return :missing unless delivery

        user_id = delivery.domain_event.domain_event_stream.user_id
        Identity::User.transaction do
          user = Identity::User.lock.find_by(id: user_id)
          delivery = EventDelivery.lock.find_by(id: delivery_id, subscriber: subscription.name)
          return :missing unless delivery
          return :not_due unless delivery.due_for_attempt?
          return :blocked if delivery.predecessor_pending?(subscription)

          unless user&.active?
            return delivery.skip!
          end

          delivery.start_attempt!
          begin
            EventDelivery.transaction(requires_new: true) do
              outcome = subscription.handler.call(event: delivery.domain_event, user:)
              delivery.complete!(outcome)
            rescue ActiveRecord::Rollback
              raise ArgumentError, "Handler rolled back without a delivery outcome"
            end
          rescue StandardError => error
            delivery.reload.record_failure!(error)
          end
        end
      end
    end
  end
end
