module Views
  module Identity
    class RecoveryNew < ::Views::Base
      def initialize(delivery_error: nil)
        @delivery_error = delivery_error
      end

      def view_template
        page(title: t("identity.recovery.request_title"), narrow: true) do
          p { t("identity.recovery.request_explanation") }
          p(role: "alert", class: "ui-errors") { @delivery_error } if @delivery_error.present?
          form_with(url: password_reset_path) do
            field(name: "email_address", id: "email_address", label: t("identity.sessions.email"), type: :email, required: true, autocomplete: "email")
            submit(t("identity.recovery.request_submit"))
          end
          text_link(t("identity.sessions.sign_in"), new_session_path)
        end
      end
    end
  end
end
