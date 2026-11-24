module Views
  module Ratings
    class Stale < ::Views::Base
      def initialize(error:, rating_film:)
        @error, @rating_film = error, rating_film
      end

      def view_template
        page(title: t("ratings.browser.title"), heading_outside_card: true, after_body: method(:return_to_library)) do
          p(role: "alert") { @error }
          p { text_link(t("ratings.browser.reload"), edit_rating_path(film_id: @rating_film.film_id)) }
        end
      end

      private

      def return_to_library
        div(class: "ui-secondary-links") do
          text_link(t("library.browser.return"), library_path(view: ::Library::CollectionManagement::BrowseFilmCollection::Views::WATCHED))
        end
      end
    end
  end
end
