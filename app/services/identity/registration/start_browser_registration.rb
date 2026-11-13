module Identity
  module Registration
    class StartBrowserRegistration
      def self.call(previous_id:, guest_user_id:, **credentials)
        registration = SubmitRegistration.call(previous_id:, guest_user_id:, **credentials)
        yield registration.id
        DeliverRegistrationConfirmation.call(pending_registration_id: registration.id)
      end
    end
  end
end
