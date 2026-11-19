module DomainEvents
  module Delivery
    class Wake
      def self.call
        # One dispatcher can serve unrelated publishers. Each delivery uses its own durable trace context.
        job = OpenTelemetry::Context.with_current(OpenTelemetry::Context.empty) { DispatchDomainEventsJob.perform_later }
        Rails.logger.warn("Domain event wakeup was not enqueued; periodic polling will recover") unless job
      rescue StandardError => error
        # Publication is already committed. Neither leak payloads nor report a failed user action.
        Rails.logger.warn("Domain event wakeup failed (#{error.class.name}); periodic polling will recover")
      end
    end
  end
end
