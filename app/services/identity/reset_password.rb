module Identity
  class ResetPassword
    def self.call(token:, password:, password_confirmation:)
      raise PasswordResetUnavailable unless token.is_a?(String) && token.present?

      UserRegistered.transaction(requires_new: true) do
        user = UserRegistered.lock.find_by_token_for(:password_reset, token)
        raise PasswordResetUnavailable unless user

        user.reset_password!(password:, password_confirmation:)
      end
    end
  end
end
