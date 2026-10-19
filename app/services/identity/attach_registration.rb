module Identity
  class AttachRegistration
    def self.call(pending_registration_id:, guest_user_id:)
      PendingRegistration.transaction(requires_new: true) do
        guest = GuestUser.active.lock.find_by(id: guest_user_id)
        registration = PendingRegistration.lock.find_by(id: pending_registration_id)
        raise RegistrationUnavailable unless guest.present? && guest.active? && registration.present? && registration.active?

        if (registration.guest_user_id.present? && registration.guest_user_id != guest.id) ||
            PendingRegistration.where(guest_user_id: guest.id).where.not(id: registration.id).exists?
          raise RegistrationConflict
        end
        registration.update!(guest_user_id: guest.id) if registration.guest_user_id.nil?
        registration
      end
    end
  end
end
