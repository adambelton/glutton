module Views
  module Identity
    class RegistrationUnavailable < ::Views::Base
      def view_template
        page(title: t("identity.registration.unavailable_title"), narrow: true) do
          p(role: "alert") { t("identity.registration.unavailable") }
          text_link(t("identity.registration.restart"), new_registration_path)
          text_link(t("identity.sessions.sign_in"), new_session_path)
        end
      end
    end
  end
end
