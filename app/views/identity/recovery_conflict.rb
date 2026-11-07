module Views
  module Identity
    class RecoveryConflict < ::Views::Base
      def view_template
        page(title: t("identity.registration.conflict_title"), narrow: true) do
          p(role: "alert") { t("identity.recovery.conflict") }
          render Shared::ActionButton.new(text: t("identity.sessions.sign_out"), url: session_path, method: :delete)
        end
      end
    end
  end
end
