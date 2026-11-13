module Registry
  class FilmPoster < Shared::Base
    def initialize(film: nil, title: film.title, path: film.tmdb_details.poster_path, placeholder: :title)
      @title, @path = title, path
      @placeholder = placeholder
    end

    def view_template
      if @path.present? && @path.match?(/\A\/[a-zA-Z0-9_-]+\.(?:jpg|png|webp)\z/)
        img(src: "https://image.tmdb.org/t/p/w500#{@path}", alt: t("registry.film_presentation.poster", title: @title),
          width: "500", height: "750", class: "film-poster", referrerpolicy: "no-referrer")
      else
        branded = @placeholder == :wordmark
        div(class: [ "film-poster", "poster-placeholder", ("poster-wordmark" if branded) ],
          role: "img", aria: { label: t("registry.film_presentation.no_poster", title: @title) }) do
          span { branded ? t("ui.short_wordmark") : @title }
        end
      end
    end
  end
end
