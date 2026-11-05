module Views
  module Identity
    class Deleted < ::Views::Base
      def view_template
        page(title: t("identity.sessions.deleted_title"), narrow: true, account_controls: false, pending_reminder: false) do
          p { t("identity.sessions.deleted_description") }
          render UI::ActionButton.new(text: t("identity.sessions.sign_out"), url: session_path, method: :delete)
          text_link(t("identity.sessions.sign_in"), new_session_path)
        end
      end
    end
  end
end
