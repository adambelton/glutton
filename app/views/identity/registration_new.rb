module Views
  module Identity
    class RegistrationNew < ::Views::Base
      def initialize(registration:)
        @registration = registration
      end

      def view_template
        terms_version = ::Identity::TermsOfService.current.version
        privacy_notice_version = ::Identity::PrivacyNotice.current.version
        page(title: t("identity.registration.title"), narrow: true) do
          p { t("identity.registration.explanation") }
          errors(@registration.errors.full_messages)
          form_with(url: registration_path, scope: :registration) do
            input(type: :hidden, name: "registration[terms_version]", value: terms_version)
            input(type: :hidden, name: "registration[privacy_notice_version]", value: privacy_notice_version)
            field(name: "registration[email_address]", id: "registration_email_address", label: t("identity.sessions.email"), type: :email, value: @registration.email_address, required: true, autocomplete: "email")
            field(name: "registration[password]", id: "registration_password", label: t("identity.sessions.password"), type: :password, required: true, autocomplete: "new-password")
            field(name: "registration[password_confirmation]", id: "registration_password_confirmation", label: t("identity.registration.password_confirmation"), type: :password, required: true, autocomplete: "new-password")
            label(for: "registration_terms_accepted", class: "registration-terms") do
              input(type: :checkbox, id: "registration_terms_accepted", name: "registration[terms_accepted]", value: "1", required: true)
              span { t("identity.registration.terms_acceptance") }
            end
            submit(t("identity.registration.submit"))
          end
          div(class: "registration-policies") do
            text_link(t("identity.terms_of_service.title"), terms_of_service_path(version: terms_version))
            text_link(t("identity.privacy_notice.title"), privacy_notice_path(version: privacy_notice_version))
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
