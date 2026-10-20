module Identity
  class PrepareRegistration
    def self.call(email_address:, password:, password_confirmation:, guest_user_id: nil)
      attributes = { email_address:, password:, password_confirmation: }
      # Always validate fresh credentials, including on replacement. An existing
      # digest must not make a blank replacement password valid.
      registration = PendingRegistration.new(attributes)

      return registration.tap(&:save!) if guest_user_id.nil?

      PendingRegistration.transaction do
        user = User.lock.find_by(id: guest_user_id)
        # Check current permission after acquiring the user lock.
        raise RegistrationUnavailable unless user&.can_register?

        registration.guest_user = user
        registration.validate!
        PendingRegistration.where(guest_user_id: user.id).delete_all
        registration.save!
        registration
      end
    end
  end
end
