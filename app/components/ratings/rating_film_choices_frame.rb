module Ratings
  class RatingFilmChoicesFrame < Shared::Base
    def initialize(catalogue:)
      @catalogue = catalogue
    end

    def view_template
      tag(:turbo_frame, id: "rating-catalogue-#{@catalogue.number}") do
        @catalogue.films.each do |film|
          div(class: "rating-film-option") do
            label(class: "rating-film-choice") do
              title_id = "rating-film-title-#{film.id}"
              input(type: "checkbox", name: "film_ids[]", value: film.id, aria: { labelledby: title_id })
              render Registry::FilmPoster.new(film:, placeholder: :wordmark)
              span(id: title_id, class: "rating-film-choice-title") { render Registry::FilmTitle.new(film:) }
            end
          end
        end
        if @catalogue.next_number.present?
          tag(:turbo_frame, id: "rating-catalogue-#{@catalogue.next_number}", loading: "lazy",
            class: "rating-catalogue-next", src: choose_films_rating_path(page: @catalogue.next_number)) do
            div(class: "rating-catalogue-loading", role: "status") do
              span(class: "ui-spinner", aria: { hidden: true })
              span(class: "sr-only") { t("ratings.onboarding.loading") }
            end
          end
        end
      end
    end
  end
end
