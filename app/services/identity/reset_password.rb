module Identity
  class ResetPassword
    def self.call(token:, password:, password_confirmation:)
      raise PasswordResetUnavailable unless token.is_a?(String) && token.present?

      UserRegistered.transaction(requires_new: true) do
        user = UserRegistered.lock.find_by_token_for(:password_reset, token)
        raise PasswordResetUnavailable unless user.present? && user.active? && user.email_confirmed_at.present?

        user.assign_attributes(password:, password_confirmation:)
        user.save!(context: :password_reset)
        Session.where(user_id: user.id).delete_all
        user
      end
    end
  end
end
