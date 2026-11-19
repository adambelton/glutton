module Monitoring
  module Instrumentation
    def instrument_class_operations(*methods)
      instrument_operations_on(singleton_class, methods, ".")
    end

    def instrument_operations(*methods)
      instrument_operations_on(self, methods, "#")
    end

    private

    def instrument_operations_on(target, methods, separator)
      owner = name
      domain = owner.split("::").first
      wrapper = Module.new
      methods.each do |method|
        operation = "#{owner}#{separator}#{method}".freeze
        wrapper.define_method(method) do |*args, **kwargs, &block|
          ActiveSupport::Notifications.instrument(ActivityMonitoring::BUSINESS_OPERATION, operation:, domain:) do
            super(*args, **kwargs, &block)
          end
        end
      end
      target.prepend(wrapper)
    end
  end
end
