module Views
  module Ratings
    class New < ::Views::Base
      def initialize(rating_film:, requested_film_id:, value: nil, notes: nil, errors: nil)
        @rating_film, @requested_film_id, @value = rating_film, requested_film_id, value
        @notes, @errors = notes, errors
      end

      def view_template
        page(title: t("ratings.browser.title"), heading_outside_card: true) do
          if @rating_film.present?
            render ::Ratings::Form.new(film: @rating_film.film, rating_film_id: @rating_film.id, method: :post, value: @value, notes: @notes, errors: @errors, dismissible: @requested_film_id.blank?, requested_film_id: @requested_film_id)
            if @requested_film_id.present?
              p { text_link(t("library.browser.return"), library_path(view: ::Library::CollectionManagement::BrowseFilmCollection::Views::WATCHED)) }
            end
          else
            p(class: "ui-empty") { t("ratings.browser.empty") }
          end
        end
      end
    end
  end
end
