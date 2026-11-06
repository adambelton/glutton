module Views
  module Ratings
    class Edit < ::Views::Base
      def initialize(rating_film:, previous_rating_id:, value:, expression_texts:, expression_draft: nil, errors: nil)
        @rating_film, @previous_rating_id, @value = rating_film, previous_rating_id, value
        @expression_draft = expression_draft
        @expression_texts, @errors = expression_texts, errors
      end

      def view_template
        page(title: t("ratings.browser.edit_title")) do
          render ::Ratings::Form.new(film: @rating_film.film, rating_film_id: @rating_film.id, method: :patch, previous_rating_id: @previous_rating_id, value: @value, expression_texts: @expression_texts, expression_draft: @expression_draft, errors: @errors)
          p { text_link(t("ratings.browser.continue"), new_rating_path) }
        end
      end
    end
  end
end
