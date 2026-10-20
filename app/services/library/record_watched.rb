module Library
  class RecordWatched
    def self.call(user_id:, film_id:)
      LibraryFilm.transaction do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable, "An active identity is required" unless user&.active?

        film = Film.find_by(id: film_id)
        raise FilmUnavailable, "Film is unavailable" unless film

        library_film = LibraryFilm.lock.find_by(user_id: user.id, film_id: film.id)
        if library_film
          library_film.record_watched
        else
          LibraryFilmWatched.create!(user:, film:)
        end
      end
    end
  end
end
