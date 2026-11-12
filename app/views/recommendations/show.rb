module Views
  module Recommendations
    class Show < ::Views::Base
      def initialize(result:, film:, watched_film_id:)
        @result, @film, @watched_film_id = result, film, watched_film_id
      end

      def view_template
        page(title: t("recommendations.title"), heading_outside_card: true) do
          if @watched_film_id.present?
            p { text_link(t("recommendations.rate_watched"), new_rating_path(film_id: @watched_film_id)) }
          end
          if @film.present?
            article do
              render ::Registry::FilmPoster.new(film: @film)
              h2 { @film.title }
              render ::Registry::FilmLinks.new(film: @film)
              overview = @film.tmdb_details.overview
              p { overview } if overview.present?
              div(class: "ui-actions") do
                params = { film_id: @film.id }
                render Shared::ActionButton.new(text: t("recommendations.accept"), url: accept_recommendation_path, params:)
                render Shared::ActionButton.new(text: t("recommendations.reject"), url: reject_recommendation_path, params:)
                render Shared::ActionButton.new(text: t("library.detail.mark_watched"), url: mark_watched_from_recommendations_path, params:)
              end
            end
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
