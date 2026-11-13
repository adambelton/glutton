module Views
  module Ratings
    class ChooseRatingFilms < ::Views::Base
      def initialize(catalogue:, error: nil)
        @catalogue, @error = catalogue, error
      end

      def view_template
        minimum = ::Ratings::CandidateSelection::InitialRatingFilmSelection::MINIMUM_FILMS
        if @catalogue.films.any?
          data = { controller: "rating-film-selection", rating_film_selection_minimum_value: minimum,
            action: "scroll@window->rating-film-selection#updateStickyBorder resize@window->rating-film-selection#updateStickyBorder" }
        end
        page(title: t("ratings.onboarding.choose"), heading_outside_card: true, data:) do
          errors([ @error ]) if @error.present?
          div(class: "ui-actions rating-picker-actions", data: { rating_film_selection_target: "actions" }) do
            if @catalogue.films.any?
              render Shared::PrimaryButton.new(type: :submit, form: "rating-film-picker", class: "ui-action-button",
                aria: { describedby: "rating-picker-instructions" },
                data: { rating_film_selection_target: "start" }) { t("ratings.onboarding.start") }
            end
            render Shared::ActionForm.new(url: surprise_rating_path,
              data: { turbo: false }) do
              render Shared::GhostButton.new(type: :submit, class: "ui-action-button") { t("ratings.onboarding.cancel") }
            end
            if @catalogue.films.any?
              p(id: "rating-picker-instructions") { t("ratings.onboarding.instructions", count: minimum) }
            end
          end
          if @catalogue.films.any?
            form_with(url: queue_films_rating_path, method: :post, id: "rating-film-picker", class: "rating-film-picker",
              data: { rating_film_selection_target: "form", action: "change->rating-film-selection#update" }) do
              fieldset(aria: { labelledby: "rating-picker-instructions" }) do
                div(class: "poster-grid") { render ::Ratings::RatingFilmChoicesFrame.new(catalogue: @catalogue) }
              end
            end
          else
            p(class: "ui-empty") { t("ratings.onboarding.empty") }
          end
        end
      end
    end
  end
end
