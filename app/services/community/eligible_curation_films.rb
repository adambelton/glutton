module Community
  class EligibleCurationFilms
    def initialize(member:)
      @watched = Library::LibraryFilm.watched.where(user_id: member.id).preload(:film)
    end

    def choices(excluding_film_ids: [])
      horror_films(@watched.where.not(film_id: excluding_film_ids)).sort_by { |film| [ film.title.downcase, film.id ] }
    end

    def lock_for_submission(film_ids:)
      horror_films(@watched.where(film_id: film_ids).order(:film_id).lock)
    end

    private

    def horror_films(library_films)
      library_films.map(&:film).select { |film| film.tmdb_details.genre_names.include?("Horror") }
    end
  end
end
