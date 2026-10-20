module Library
  class RecordWatched
    def self.call(user_id:, film_id:)
      LibraryFilm.transaction do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable, "An active identity is required" unless user&.active?

        film = Film.find_by(id: film_id)
        raise FilmUnavailable, "Film is unavailable" unless film

        library_film = LibraryFilm.lock.find_by(user_id: user.id, film_id: film.id)
        if library_film.nil?
          LibraryFilmWatched.create!(user:, film:)
        elsif library_film.can_watch?
          watched = library_film.becomes!(LibraryFilmWatched)
          watched.save!
          watched
        else
          library_film.record_watched
        end
      end
    end
  end
end
