module Community
  class CurationReferenceFilms
    def initialize(author:)
      @watched = Library::LibraryFilm.watched.where(user_id: author.id).preload(:film)
    end

    def choices
      horror_films(@watched).sort_by { |film| [ film.title.downcase, film.id ] }
    end

    def for_publication(film_ids:)
      horror_films(@watched.where(film_id: film_ids).order(:film_id).lock)
    end

    private

    def horror_films(library_films)
      library_films.map(&:film).select { |film| film.tmdb_details.genre_names.include?("Horror") }
    end
  end
end
