module DomainEvents
  class Wake
    def self.call
      job = DispatchDomainEventsJob.perform_later
      Rails.logger.warn("Domain event wakeup was not enqueued; periodic polling will recover") unless job
    rescue StandardError => error
      # Publication is already committed. Neither leak payloads nor report a failed user action.
      Rails.logger.warn("Domain event wakeup failed (#{error.class.name}); periodic polling will recover")
    end
  end
end
