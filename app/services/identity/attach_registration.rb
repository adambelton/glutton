module Identity
  class AttachRegistration
    def self.call(pending_registration_id:, guest_user_id:)
      PendingRegistration.transaction(requires_new: true) do
        user = User.lock.find_by(id: guest_user_id)
        registration = PendingRegistration.lock.find_by(id: pending_registration_id)
        raise RegistrationUnavailable unless user.present? && user.can_register? && registration.present? && registration.active?

        registration.attach_to!(user: user)
      end
    end
  end
end
