module Identity
  module Registration
    class StartBrowserRegistration
      extend Monitoring::Instrumentation
      instrument_class_operations :call, expected_failure: ->(error) { registration_input_invalid?(error) }

      def self.call(previous_id:, guest_user_id:, **credentials)
        registration = SubmitRegistration.call(previous_id:, guest_user_id:, **credentials)
        yield registration.id
        DeliverRegistrationConfirmation.call(pending_registration_id: registration.id)
      end

      def self.registration_input_invalid?(error)
        return false unless error.is_a?(ActiveRecord::RecordInvalid) && error.record.is_a?(PendingRegistration) && error.record.new_record?

        fields = error.record.errors.attribute_names
        fields.present? && (fields - %i[email_address password password_digest password_confirmation]).empty?
      end
      private_class_method :registration_input_invalid?
    end
  end
end
