module Registry
  class FilmPoster < Shared::Base
    def initialize(film:)
      @film = film
    end

    def view_template
      path = @film.tmdb_details.poster_path
      if path.present? && path.match?(/\A\/[a-zA-Z0-9_-]+\.(?:jpg|png|webp)\z/)
        img(src: "https://image.tmdb.org/t/p/w500#{path}", alt: t("registry.film_presentation.poster", title: @film.title),
          width: "500", height: "750", class: "film-poster", referrerpolicy: "no-referrer")
      else
        div(class: "film-poster poster-placeholder", role: "img", aria: { label: t("registry.film_presentation.no_poster", title: @film.title) }) do
          span { @film.title }
        end
      end
    end
  end
end
