module Views
  module Ratings
    class Edit < ::Views::Base
      def initialize(rating_film:, previous_rating_id:, value:, notes:, errors: nil)
        @rating_film, @previous_rating_id, @value = rating_film, previous_rating_id, value
        @notes, @errors = notes, errors
      end

      def view_template
        page(title: t("ratings.browser.edit_title")) do
          render ::Ratings::Form.new(film: @rating_film.film, rating_film_id: @rating_film.id, method: :patch, previous_rating_id: @previous_rating_id, value: @value, notes: @notes, errors: @errors)
          p { text_link(t("ratings.browser.continue"), new_rating_path) }
        end
      end
    end
  end
end
