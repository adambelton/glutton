module Views
  module Identity
    class RecoveryConflict < ::Views::Base
      def view_template
        page(title: t("identity.registration.conflict_title"), narrow: true) do
          p(role: "alert") { t("identity.recovery.conflict") }
          render Shared::ActionForm.new(url: session_path, method: :delete) do
            render Shared::GhostButton.new(type: :submit, class: "ui-action-button") { t("identity.sessions.sign_out") }
          end
        end
      end
    end
  end
end
