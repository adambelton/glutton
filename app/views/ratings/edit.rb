module Views
  module Ratings
    class Edit < ::Views::Base
      def initialize(rating_film:, previous_rating_id:, value:, notes:, saved_rating:, errors: nil)
        @rating_film, @previous_rating_id, @value = rating_film, previous_rating_id, value
        @notes, @errors, @saved_rating = notes, errors, saved_rating
      end

      def view_template
        page(title: t("ratings.browser.title"), heading_outside_card: true, after_body: method(:return_to_library)) do
          render ::Ratings::Form.new(film: @rating_film.film, rating_film_id: @rating_film.id, method: :patch, previous_rating_id: @previous_rating_id, value: @value, notes: @notes, errors: @errors, saved_rating: @saved_rating)
        end
      end

      private

      def return_to_library
        div(class: "ui-secondary-links") do
          text_link(t("library.browser.return"), library_path(view: ::Library::CollectionManagement::InspectFilmCollection::Views::WATCHED))
        end
      end
    end
  end
end
