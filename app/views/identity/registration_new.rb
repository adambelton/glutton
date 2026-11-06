module Views
  module Identity
    class RegistrationNew < ::Views::Base
      def initialize(registration:)
        @registration = registration
      end

      def view_template
        page(title: t("identity.registration.title"), narrow: true) do
          p { t("identity.registration.explanation") }
          errors(@registration.errors.full_messages)
          form_with(url: registration_path, scope: :registration) do
            field(name: "registration[email_address]", id: "registration_email_address", label: t("identity.sessions.email"), type: :email, value: @registration.email_address, required: true, autocomplete: "email")
            field(name: "registration[password]", id: "registration_password", label: t("identity.sessions.password"), type: :password, required: true, autocomplete: "new-password")
            field(name: "registration[password_confirmation]", id: "registration_password_confirmation", label: t("identity.registration.password_confirmation"), type: :password, required: true, autocomplete: "new-password")
            submit(t("identity.registration.submit"))
          end
          div(class: "ui-secondary-links") do
            text_link(t("identity.sessions.sign_in"), new_session_path)
            text_link(t("identity.entry.back"), browsing_path)
          end
        end
      end
    end
  end
end
