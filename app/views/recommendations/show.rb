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
            details = @film.tmdb_details
            video_id = details.youtube_trailer_id
            render Shared::FilmCard.new(layout: "recommendation-film", data: ({ controller: "recommendation-trailer",
              action: "keydown.esc->recommendation-trailer#collapse resize@window->recommendation-trailer#fitViewport" } if video_id.present?)) do
              div(class: "recommendation-artwork") { render ::Registry::FilmPoster.new(film: @film) }
              div(class: "recommendation-details") do
                h2 { render ::Registry::FilmTitle.new(film: @film) }
                render ::Registry::FilmLinks.new(film: @film)
                overview = details.overview
                p(class: "recommendation-synopsis") { overview } if overview.present?
              end
              div(class: "recommendation-response") do
                trailer(video_id:) if video_id.present?
                div(class: "film-actions recommendation-actions") do
                  params = { film_id: @film.id }
                  render Shared::ActionButton.new(text: t("recommendations.accept"), variant: :primary, url: accept_recommendation_path, params:)
                  render Shared::ActionButton.new(text: t("recommendations.reject"), variant: :ghost, url: reject_recommendation_path, params:)
                  render Shared::ActionButton.new(text: t("library.detail.add_to_watched"), variant: :secondary, icon: ::Library::EyeCheck.new, url: add_to_watched_from_recommendations_path, params:)
                end
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

      private

      def trailer(video_id:)
        div(class: "recommendation-trailer") do
          div(class: "recommendation-trailer-frame") do
            iframe(id: "recommendation-trailer-player", src: "https://www.youtube.com/embed/#{video_id}", title: t("recommendations.trailer_for", title: @film.title),
              loading: "lazy", allowfullscreen: true)
            button(type: "button", class: "recommendation-trailer-toggle", hidden: true,
              aria: { controls: "recommendation-trailer-player", expanded: "false", label: t("recommendations.expand_trailer") },
              data: { recommendation_trailer_target: "toggle", action: "recommendation-trailer#toggle",
                expand_label: t("recommendations.expand_trailer"), collapse_label: t("recommendations.collapse_trailer") }) do
              svg(viewBox: "0 0 24 24", width: "20", height: "20", fill: "none", stroke: "currentColor",
                stroke_width: "1.75", stroke_linecap: "round", stroke_linejoin: "round", aria: { hidden: true }) do |icon|
                icon.path(class: "trailer-expand-icon", d: "M9 3H3v6m12-6h6v6M3 15v6h6m12-6v6h-6")
                icon.path(class: "trailer-collapse-icon", d: "M3 9h6V3m12 6h-6V3M9 21v-6H3m12 6v-6h6")
              end
            end
          end
        end
      end
    end
  end
end
