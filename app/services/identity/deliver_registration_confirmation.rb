require "net/smtp"
require "uri"

module Identity
  class DeliverRegistrationConfirmation
    class Limited < StandardError; end
    class Exhausted < Limited; end
    class Failed < StandardError; end

    def self.call(pending_registration_id:)
      origin = validated_origin
      recipient, token = PendingRegistration.transaction(requires_new: true) do
        registration = PendingRegistration.lock.find_by(id: pending_registration_id)
        raise RegistrationUnavailable unless registration.present? && registration.active?
        raise RegistrationUnavailable if RegisteredUser.exists?(email_address: registration.email_address)
        raise Exhausted if registration.confirmation_delivery_attempts >= 5
        if registration.confirmation_delivery_attempted_at.present? && registration.confirmation_delivery_attempted_at > 60.seconds.ago
          raise Limited
        end
        registration.update!(confirmation_delivery_attempts: registration.confirmation_delivery_attempts + 1,
          confirmation_delivery_attempted_at: Time.current)
        [ registration.email_address, RegistrationConfirmation.token_for(pending_registration_id: registration.id) ]
      end
      url = origin + Rails.application.routes.url_helpers.registration_confirmation_path(token:)
      begin
        AccountMailer.confirmation(recipient:, confirmation_url: url).deliver_now
      rescue Net::SMTPError, Timeout::Error, IOError, SocketError, SystemCallError, OpenSSL::SSL::SSLError
        raise Failed, cause: nil
      end
    end

    def self.validated_origin
      begin
        uri = URI.parse(ENV.fetch("APP_ORIGIN", ""))
      rescue URI::InvalidURIError
        uri = nil
      end
      local_http = uri.present? && uri.scheme == "http" && %w[localhost 127.0.0.1 ::1].include?(uri.host) &&
        Rails.env.development?
      unless uri.present? && uri.host.present? && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil? &&
          [ "", "/" ].include?(uri.path) && (uri.scheme == "https" || local_http)
        raise ArgumentError, "APP_ORIGIN must be a root HTTPS origin (localhost HTTP is allowed in development)"
      end
      uri.to_s.delete_suffix("/")
    end
    private_class_method :validated_origin
  end
end
