module Identity
  class RegistrationConfirmation
    def self.token_for(pending_registration_id:)
      registration = PendingRegistration.find_by(id: pending_registration_id)
      raise RegistrationUnavailable unless registration.present? && registration.active?

      registration.generate_token_for(:email_confirmation)
    end
  end
end
