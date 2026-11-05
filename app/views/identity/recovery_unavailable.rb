module Views
  module Identity
    class RecoveryUnavailable < ::Views::Base
      def view_template
        page(title: t("identity.recovery.unavailable_title"), narrow: true) do
          p(role: "alert") { t("identity.recovery.unavailable") }
          text_link(t("identity.recovery.request_title"), new_password_reset_path)
          text_link(t("identity.sessions.sign_in"), new_session_path)
        end
      end
    end
  end
end
