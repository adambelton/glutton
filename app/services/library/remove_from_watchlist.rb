module Library
  class RemoveFromWatchlist
    def self.call(user_id:, library_film_id:)
      LibraryFilm.transaction(requires_new: true) do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable unless user&.active?

        library_film = LibraryFilm.lock.find_by(user_id: user.id, id: library_film_id)
        raise FilmUnavailable unless library_film
        raise NotOnWatchlist unless library_film.can_remove_from_watchlist?

        library_film.destroy!
        library_film.publish_event!(name: Events::FILM_REMOVED_FROM_WATCHLIST)
        library_film
      end
    end
  end
end
