module Views
  module Identity
    class RegistrationPending < ::Views::Base
      def initialize(registration:)
        @registration = registration
      end

      def view_template
        page(title: t("identity.registration.pending_title"), narrow: true, pending_reminder: false) do
          render ::Identity::PendingDetails.new(registration: @registration)
          render Shared::ActionButton.new(text: t("identity.registration.resend"), url: registration_email_path)
          text_link(t("identity.registration.restart"), new_registration_path)
          text_link(t("identity.registration.continue"), root_path)
        end
      end
    end
  end
end
