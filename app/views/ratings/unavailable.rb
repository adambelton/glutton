module Views
  module Ratings
    class Unavailable < ::Views::Base
      def initialize(error:)
        @error = error
      end

      def view_template
        page(title: t("ratings.browser.title")) do
          p(role: "alert") { @error }
          text_link(t("ratings.browser.continue"), new_rating_path)
        end
      end
    end
  end
end
