require "net/smtp"

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
        raise RegistrationUnavailable if UserRegistered.exists?(email_address: registration.email_address)
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
      MailOrigin.call
    end
    private_class_method :validated_origin
  end
end
