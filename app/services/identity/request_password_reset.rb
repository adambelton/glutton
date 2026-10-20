require "net/smtp"

module Identity
  class RequestPasswordReset
    class Failed < StandardError; end

    def self.call(email_address:)
      user = UserRegistered.find_by_email(email_address)
      return unless user&.can_reset_password?

      url = MailOrigin.call + Rails.application.routes.url_helpers.edit_password_reset_path(token: user.password_reset_token)
      begin
        AccountMailer.password_reset(recipient: user.email_address, reset_url: url).deliver_now
      rescue Net::SMTPError, Timeout::Error, IOError, SocketError, SystemCallError, OpenSSL::SSL::SSLError
        raise Failed, cause: nil
      end
      nil
    end
  end
end
