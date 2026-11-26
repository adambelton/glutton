module Library
  class FilmGrid < Shared::Base
    def initialize(entries:, link_titles:)
      @entries, @link_titles = entries, link_titles
    end

    def view_template(&block)
      ul(class: "library-films") do
        @entries.each_with_index do |library_film, index|
          li(class: "library-film") do
            film = library_film.film
            render ::Registry::FilmPoster.new(film:)
            if block.present?
              yield library_film, index
            else
              render ::Library::LibraryFilmCardControls.new(library_film:)
            end
            h3 { film_title(film) }
          end
        end
      end
    end

    private

    def film_title(film)
      title = ::Registry::FilmTitle.new(film:)
      return render title unless @link_titles && film.tmdb_id.present?

      a(href: "https://www.themoviedb.org/movie/#{film.tmdb_id}", class: "library-film-title-link",
        target: "_blank", rel: "noopener noreferrer", title: t("ui.open_film_on_tmdb")) { render title }
    end
  end
end
