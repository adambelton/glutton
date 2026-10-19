module Identity
  class Authenticate
    def self.call(email_address:, password:)
      return unless email_address.is_a?(String) && password.is_a?(String)
      return if email_address.blank? || password.blank?

      email = RegisteredUser.normalize_value_for(:email_address, email_address)
      return unless URI::MailTo::EMAIL_REGEXP.match?(email)

      user = RegisteredUser.authenticate_by(email_address: email, password: password)
      return unless user&.active? && user.email_confirmed_at.present?

      Session.create!(user: user)
    end
  end
end
