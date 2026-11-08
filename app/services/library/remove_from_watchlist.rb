module Library
  class RemoveFromWatchlist
    def self.call(user_id:, library_film_id:)
      LibraryFilm.transaction(requires_new: true) do
        user = Identity::User.lock.find_by(id: user_id)
        raise IdentityUnavailable unless user&.active?

        library_film = LibraryFilm.lock.find_by(user_id: user.id, id: library_film_id)
        raise FilmUnavailable unless library_film.present?

        library_film.remove_from_watchlist!
      end
    end
  end
end
