require "uri"

module Glutton
  module MailDelivery
    def self.settings(environment:, env: ENV)
      base = { delivery_method: :test, default_options: { from: "noreply@example.test" },
        show_previews: environment == "development", raise_delivery_errors: true, logger: nil }
      return base if environment == "test"

      mode = env.fetch("MAIL_DELIVERY", "test")
      return base if mode == "test"
      raise ArgumentError, "Unknown MAIL_DELIVERY mode" unless mode == "resend"

      key = env["RESEND_API_KEY"]
      sender = env["MAIL_FROM"]
      raise ArgumentError, "RESEND_API_KEY is required for Resend" if key.nil? || key.strip.empty?
      unless sender.is_a?(String) && sender.match?(URI::MailTo::EMAIL_REGEXP) && !sender.match?(/[\s,;<>]/)
        raise ArgumentError, "MAIL_FROM must be a single email address"
      end

      base.merge(delivery_method: :smtp, default_options: { from: sender }, smtp_settings: {
        address: "smtp.resend.com", port: 587, user_name: "resend", password: key,
        authentication: :plain, enable_starttls: true, openssl_verify_mode: "peer",
        open_timeout: 10, read_timeout: 10
      })
    end
  end
end
