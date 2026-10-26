module Library
  class AddToWatchlist
    def self.call(user_id:, library_film_id:)
      LibraryFilm.transaction(requires_new: true) do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable unless user&.active?

        library_film = LibraryFilm.lock.find_by(user_id: user.id, id: library_film_id)
        raise FilmUnavailable unless library_film
        raise WatchlistUnavailable unless library_film.can_add_to_watchlist?

        library_film = library_film.becomes!(LibraryFilmToWatch)
        library_film.save!
        library_film.publish_event!(name: Events::FILM_ADDED_TO_WATCHLIST)
        library_film
      end
    end
  end
end
