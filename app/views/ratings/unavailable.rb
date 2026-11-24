module Views
  module Ratings
    class Unavailable < ::Views::Base
      def initialize(error:)
        @error = error
      end

      def view_template
        page(title: t("ratings.browser.title"), back_to: new_rating_path, back_label: t("ratings.browser.continue")) do
          p(role: "alert") { @error }
        end
      end
    end
  end
end
