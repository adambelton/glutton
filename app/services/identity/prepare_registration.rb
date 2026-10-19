module Identity
  class PrepareRegistration
    def self.call(email_address:, password:, password_confirmation:, guest_user_id: nil)
      attributes = { email_address:, password:, password_confirmation: }
      # Always validate fresh credentials, including on replacement. An existing
      # digest must not make a blank replacement password valid.
      registration = PendingRegistration.new(attributes)

      return registration.tap(&:save!) if guest_user_id.nil?

      PendingRegistration.transaction do
        guest = GuestUser.active.lock.find_by(id: guest_user_id)
        # Lock contention can carry a guest past the deadline used by the scope.
        raise RegistrationUnavailable unless guest&.active?

        registration.guest_user = guest
        registration.validate!
        PendingRegistration.where(guest_user_id: guest.id).delete_all
        registration.save!
        registration
      end
    end
  end
end
