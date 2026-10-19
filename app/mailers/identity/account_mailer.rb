require "uri"

module Identity
  class AccountMailer < ApplicationMailer
    def confirmation(recipient:, confirmation_url:)
      compose(recipient, confirmation_url, I18n.t("identity.account_mailer.confirmation.subject"))
    end

    def password_reset(recipient:, reset_url:)
      compose(recipient, reset_url, I18n.t("identity.account_mailer.password_reset.subject"))
    end

    private

    def compose(recipient, url, subject)
      unless recipient.is_a?(String) && recipient.match?(URI::MailTo::EMAIL_REGEXP) && !recipient.match?(/[\s,;<>]/)
        raise ArgumentError, "recipient must be a single email address"
      end
      begin
        uri = URI.parse(url) if url.is_a?(String) && !url.match?(/[\r\n]/)
      rescue URI::InvalidURIError
        uri = nil
      end
      local_http = Rails.env.development? && delivery_method != :smtp && uri&.scheme == "http" && %w[localhost 127.0.0.1 ::1].include?(uri.host)
      unless uri && uri.host.present? && uri.userinfo.nil? && (uri.scheme == "https" || local_http)
        raise ArgumentError, "link must be an HTTPS URL (localhost HTTP is allowed in development)"
      end
      @link = url
      mail(to: recipient, subject: subject)
    end
  end
end
