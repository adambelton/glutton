module Monitoring
  module Instrumentation
    def instrument_class_operations(*methods, expected_failure: nil)
      instrument_operations_on(singleton_class, methods, ".", expected_failure:)
    end

    def instrument_operations(*methods)
      instrument_operations_on(self, methods, "#")
    end

    private

    def instrument_operations_on(target, methods, separator, expected_failure: nil)
      owner = name
      domain = owner.split("::").first
      wrapper = Module.new
      methods.each do |method|
        operation = "#{owner}#{separator}#{method}".freeze
        wrapper.define_method(method) do |*args, **kwargs, &block|
          ActiveSupport::Notifications.instrument(ActivityMonitoring::OPERATION_NOTIFICATION, operation:, domain:) do |payload|
            super(*args, **kwargs, &block)
          rescue StandardError => error
            payload[:expected_failure] = true if expected_failure&.call(error)
            raise
          end
        end
      end
      target.prepend(wrapper)
    end
  end
end
