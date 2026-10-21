module Library
  class RemoveFromWatchlist
    def self.call(user_id:, film_id:)
      LibraryFilm.transaction(requires_new: true) do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable, "An active identity is required" unless user&.active?

        film = Film.find_by(id: film_id)
        raise FilmUnavailable, "Film is unavailable" unless film

        library_film = LibraryFilmToWatch.lock.find_by(user_id: user.id, film_id: film.id)
        raise NotOnWatchlist, "Film is not on the watchlist" unless library_film

        library_film.destroy!
        library_film.publish_event!(name: Events::FILM_REMOVED_FROM_WATCHLIST, classification: nil)
        library_film
      end
    end
  end
end
