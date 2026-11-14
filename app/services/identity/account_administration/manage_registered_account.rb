require "net/smtp"

module Identity
  module AccountAdministration
    class ManageRegisteredAccount
      def initialize(user_id:)
        @user_id = user_id
      end

      def change_password(current_password:, password:, password_confirmation:)
        with_account do |account|
          account.authorize_credential_change!(current_password:)
          account.reset_password!(password:, password_confirmation:)
        end
      end

      def request_email_change(current_password:, email_address:)
        address, token = with_account do |account|
          account.authorize_credential_change!(current_password:)
          address = account.validate_new_email!(email_address:)
          [ address, verifier.generate([ account.id, account.email_change_version, address ],
            purpose: :confirm_email_change, expires_in: 30.minutes) ]
        end
        url = MailOrigin.call + Rails.application.routes.url_helpers.confirm_account_email_path(token:)
        AccountMailer.email_change(recipient: address, confirmation_url: url).deliver_now
      rescue Net::SMTPError, Timeout::Error, IOError, SocketError, SystemCallError, OpenSSL::SSL::SSLError
        raise Errors::EmailChangeDeliveryFailed, cause: nil
      end

      def email_change_address(token:)
        with_account { |account| verified_address(account, token) }
      end

      def confirm_email_change(token:)
        with_account do |account|
          account.change_email!(email_address: verified_address(account, token))
        end
      rescue ActiveRecord::RecordNotUnique
        raise Errors::AccountChangeUnavailable, cause: nil
      end

      def close_account
        with_account do |account|
          account.becomes!(UserDeleted).close_account!
          Session.where(user_id: account.id).delete_all
        end
      end

      private

      def with_account
        UserRegistered.transaction do
          account = UserRegistered.lock.find_by(id: @user_id)
          raise Errors::Unavailable unless account&.can_view_account?

          yield account
        end
      end

      def verified_address(account, token)
        id, version, address = verifier.verified(token, purpose: :confirm_email_change) if token.is_a?(String)
        raise Errors::AccountChangeUnavailable unless id == account.id && version == account.email_change_version

        address
      end

      def verifier
        Rails.application.message_verifier(:account_email_change)
      end
    end
  end
end
