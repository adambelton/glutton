module Views
  module Ratings
    class New < ::Views::Base
      def initialize(rating_film:, targeted:, value: nil, notes: nil, errors: nil, edited_film: nil)
        @rating_film, @targeted, @value = rating_film, targeted, value
        @notes, @errors, @edited_film = notes, errors, edited_film
      end

      def view_template
        page(title: t("ratings.browser.title"), heading_outside_card: true) do
          if @edited_film.present?
            p { text_link(t("ratings.browser.edit_saved", title: @edited_film["title"]), edit_rating_path(film_id: @edited_film["id"])) }
          end
          if @rating_film.present?
            render ::Ratings::Form.new(film: @rating_film.film, rating_film_id: @rating_film.id, method: :post, value: @value, notes: @notes, errors: @errors, dismissible: !@targeted, targeted: @targeted)
            if @targeted
              p { text_link(t("ratings.browser.continue"), new_rating_path) }
            end
          else
            p(class: "ui-empty") { t("ratings.browser.empty") }
          end
        end
      end
    end
  end
end
