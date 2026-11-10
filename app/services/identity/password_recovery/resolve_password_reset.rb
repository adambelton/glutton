module Identity
  module PasswordRecovery
    class ResolvePasswordReset
      def self.call(token:, current_user_id: nil)
        raise Errors::PasswordResetUnavailable unless token.is_a?(String) && token.present?

        user = UserRegistered.find_by_password_reset_token(token)
        raise Errors::PasswordResetUnavailable unless user&.can_reset_password?

        current_user = User.find_by(id: current_user_id) if current_user_id
        if current_user&.can_reset_password? && current_user.id != user.id
          raise Errors::PasswordResetConflict
        end

        user
      end
    end
  end
end
