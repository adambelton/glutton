module Identity
  class CompleteBrowserRegistration
    def self.call(token:, current_user_id: nil, pending_registration_id: nil)
      return CompleteRegistration.call(token:) if current_user_id.nil?

      PendingRegistration.transaction(requires_new: true) do
        user = User.lock.find_by(id: current_user_id)
        raise RegistrationConflict unless user.present? && user.can_register?
        raise RegistrationUnavailable unless token.is_a?(String) && token.present?

        registration = PendingRegistration.lock.find_by_token_for(:email_confirmation, token)
        raise RegistrationUnavailable unless registration.present? && registration.active?

        if registration.guest_user_id.nil? && registration.id == pending_registration_id
          AttachRegistration.call(pending_registration_id: registration.id, guest_user_id: user.id)
        elsif registration.guest_user_id != user.id
          raise RegistrationConflict
        end
        CompleteRegistration.call(token:)
      end
    end
  end
end
