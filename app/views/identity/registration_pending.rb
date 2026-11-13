module Views
  module Identity
    class RegistrationPending < ::Views::Base
      def initialize(registration:)
        @registration = registration
      end

      def view_template
        page(title: t("identity.registration.pending_title"), narrow: true, pending_reminder: false) do
          p(role: "status", class: "ui-reminder") { flash[:page_notice] } if flash[:page_notice].present?
          render ::Identity::PendingDetails.new(registration: @registration)
          render Shared::ActionForm.new(url: registration_email_path) do
            render Shared::GhostButton.new(type: :submit, class: "ui-action-button") { t("identity.registration.resend") }
          end
          text_link(t("identity.registration.restart"), new_registration_path)
          text_link(t("identity.registration.continue"), root_path)
        end
      end
    end
  end
end
