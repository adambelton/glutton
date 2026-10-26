module Library
  class RemoveWatchlistFilm
    def self.call(user_id:, library_film_id:)
      LibraryFilm.transaction(requires_new: true) do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable unless user&.active?

        library_film = LibraryFilm.lock.find_by(user_id: user.id, id: library_film_id)
        raise FilmUnavailable unless library_film

        RemoveFromWatchlist.call(user_id: user.id, film_id: library_film.film_id)
      end
    end
  end
end
