module Views
  module Library
    class SignedOut < ::Views::Base
      def view_template
        page(title: t("library.browser.title"), class: "library-page", heading_outside_card: true) do
          p { t("library.browser.sign_in_required") }
          text_link(t("identity.sessions.sign_in"), new_session_path)
          text_link(t("identity.registration.title"), new_registration_path)
        end
      end
    end
  end
end
