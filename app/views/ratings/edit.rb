module Views
  module Ratings
    class Edit < ::Views::Base
      def initialize(rating_film:, previous_rating_id:, value:, notes:, saved_rating:, errors: nil)
        @rating_film, @previous_rating_id, @value = rating_film, previous_rating_id, value
        @notes, @errors, @saved_rating = notes, errors, saved_rating
      end

      def view_template
        page(title: t("ratings.browser.edit_title")) do
          render ::Ratings::Form.new(film: @rating_film.film, rating_film_id: @rating_film.id, method: :patch, previous_rating_id: @previous_rating_id, value: @value, notes: @notes, errors: @errors, saved_rating: @saved_rating)
          p { text_link(t("library.browser.return"), library_path(view: ::Library::CollectionManagement::InspectFilmCollection::Views::WATCHED)) }
        end
      end
    end
  end
end
