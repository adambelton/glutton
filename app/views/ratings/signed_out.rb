module Views
  module Ratings
    class SignedOut < ::Views::Base
      def view_template
        page(title: t("ratings.browser.title")) do
          p { t("ratings.browser.sign_in_required") }
          text_link(t("ratings.browser.continue"), new_rating_path)
          text_link(t("identity.sessions.sign_in"), new_session_path)
          text_link(t("identity.registration.title"), new_registration_path)
        end
      end
    end
  end
end
