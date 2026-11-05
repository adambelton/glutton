module Views
  module Ratings
    class Stale < ::Views::Base
      def initialize(error:, rating_film:)
        @error, @rating_film = error, rating_film
      end

      def view_template
        page(title: t("ratings.browser.edit_title")) do
          p(role: "alert") { @error }
          p { text_link(t("ratings.browser.reload"), edit_rating_path(film_id: @rating_film.film_id)) }
          p { text_link(t("ratings.browser.continue"), new_rating_path) }
        end
      end
    end
  end
end
