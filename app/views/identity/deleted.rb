module Views
  module Identity
    class Deleted < ::Views::Base
      def view_template
        page(title: t("identity.sessions.deleted_title"), narrow: true, account_controls: false, pending_reminder: false) do
          p { t("identity.sessions.deleted_description") }
          render Shared::ActionForm.new(url: session_path, method: :delete) do
            render Shared::GhostButton.new(type: :submit, class: "ui-action-button") { t("identity.sessions.sign_out") }
          end
          text_link(t("identity.sessions.sign_in"), new_session_path)
        end
      end
    end
  end
end
