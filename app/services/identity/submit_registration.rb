module Identity
  class SubmitRegistration
    def self.call(previous_id: nil, guest_user_id: nil, **credentials)
      PendingRegistration.transaction(requires_new: true) do
        if guest_user_id.present?
          guest = UserGuest.active.lock.find_by(id: guest_user_id)
          raise RegistrationUnavailable unless guest.present? && guest.active?
        end
        previous = PendingRegistration.lock.find_by(id: previous_id) if previous_id.present?
        if previous_id.present? && (previous.nil? || !previous.active? ||
            (previous.guest_user_id.present? && previous.guest_user_id != guest_user_id))
          raise RegistrationUnavailable
        end
        registration = PrepareRegistration.call(guest_user_id:, **credentials)
        previous.destroy! if previous.present? && PendingRegistration.exists?(previous.id)
        registration
      end
    end
  end
end
