module Views
  module Ratings
    class New < ::Views::Base
      def initialize(rating_film:, requested_film_id:, value: nil, notes: nil, errors: nil)
        @rating_film, @requested_film_id, @value = rating_film, requested_film_id, value
        @notes, @errors = notes, errors
      end

      def view_template
        if @rating_film.present? && @requested_film_id.present?
          back_to = library_path(view: ::Library::CollectionManagement::BrowseFilmCollection::Views::WATCHED)
        end
        page(title: t("ratings.browser.title"), heading_outside_card: true, back_to:, back_label: t("library.browser.return")) do
          if @rating_film.present?
            render ::Ratings::Form.new(film: @rating_film.film, rating_film_id: @rating_film.id, method: :post, value: @value, notes: @notes, errors: @errors, dismissible: @requested_film_id.blank?, requested_film_id: @requested_film_id)
          else
            p(class: "ui-empty") { t("ratings.browser.empty") }
          end
        end
      end
    end
  end
end
