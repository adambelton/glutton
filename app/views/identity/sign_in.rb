module Views
  module Identity
    class SignIn < ::Views::Base
      def initialize(error: nil)
        @error = error
      end

      def view_template
        page(title: t("identity.sessions.sign_in"), narrow: true, account_controls: false) do
          p(role: "alert", class: "ui-errors") { @error } if @error
          form_with(url: session_path) do
            field(name: "email_address", id: "email_address", label: t("identity.sessions.email"), type: :email, required: true, autocomplete: "email", autofocus: true)
            field(name: "password", id: "password", label: t("identity.sessions.password"), type: :password, required: true, autocomplete: "current-password")
            submit(t("identity.sessions.sign_in"))
          end
          div(class: "ui-secondary-links") do
            text_link(t("identity.registration.title"), new_registration_path)
            text_link(t("identity.recovery.forgot"), new_password_reset_path)
          end
        end
      end
    end
  end
end
