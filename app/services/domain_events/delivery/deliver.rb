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

          event = delivery.domain_event
          attributes = {
            ActivityMonitoring::Attributes::EVENT_ID => event.id,
            ActivityMonitoring::Attributes::CORRELATION_ID => event.correlation_id,
            ActivityMonitoring::Attributes::SUBSCRIBER => subscription.name,
            ActivityMonitoring::Attributes::DELIVERY_ID => delivery.id,
            ActivityMonitoring::Attributes::USER_ID => user_id
          }
          outcome = ActivityMonitoring.trace_business("deliver #{event.name}", parent: Monitoring::TraceContext.parent_for_event(event.id),
            links: Array.wrap(ActivityMonitoring.link(ActivityMonitoring.traceparent)), attributes:) do
            result = user&.active? ? attempt_delivery(delivery, subscription, user:) : delivery.skip!
            ActivityMonitoring.current&.set_delivery_result(outcome: result, attempt: delivery.attempts,
              age_ms: ((Time.current - event.occurred_at) * 1000).round, error_type: delivery.last_error_class)
            result
          end
          ActiveRecord.after_all_transactions_commit do
            Rails.logger.info({ message: "domain_event_delivery", event_id: event.id,
              correlation_id: event.correlation_id, event_name: event.name, subscriber: subscription.name,
              delivery_id: delivery.id, outcome:, attempts: delivery.attempts, error_class: delivery.last_error_class }.compact.to_json)
          end
          outcome
        end
      end

      def self.attempt_delivery(delivery, subscription, user:)
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
      private_class_method :attempt_delivery
    end
  end
end
