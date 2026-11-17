module Views
  module Recommendations
    class Show < ::Views::Base
      def initialize(result:)
        @result = result
        @film = result.recommendation_film&.film
      end

      def view_template
        page(title: t("recommendations.title"), heading_outside_card: true) do
          if @film.present?
            render ::Recommendations::FilmCard.new(film: @film)
          elsif @result.unlocked?
            p(class: "ui-empty") { t("recommendations.empty") }
          else
            p(class: "ui-empty") do
              t("recommendations.progress", assessed: @result.assessed_film_count, required: @result.minimum_assessed_films)
            end
          end
        end
      end
    end
  end
end
