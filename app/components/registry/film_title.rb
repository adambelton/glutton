module Registry
  class FilmTitle < Shared::Base
    def initialize(film: nil, title: film.title, release_date: film.release_date)
      @title, @release_date = title, release_date
    end

    def view_template
      plain @title
      if @release_date.present?
        plain " "
        span(class: "film-year") { t("registry.film_presentation.year", year: @release_date.year) }
      end
    end
  end
end
