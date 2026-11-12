module Registry
  class FilmTitle < Shared::Base
    def initialize(film:)
      @film = film
    end

    def view_template
      plain @film.title
      if @film.release_date.present?
        plain " "
        span(class: "film-year") { t("registry.film_presentation.year", year: @film.release_date.year) }
      end
    end
  end
end
