module Identity
  module Registration
    class CompleteBrowserRegistration
      extend Monitoring::Instrumentation
      instrument_class_operations :call

      def self.call(token:, current_user_id: nil)
        CompleteRegistration.call(token:, current_user_id:)
      end
    end
  end
end
