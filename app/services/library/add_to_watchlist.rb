module Library
  class AddToWatchlist
    def self.call(user_id:, film_id:)
      LibraryFilm.transaction do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable, "An active identity is required" unless user&.active?

        film = Film.find_by(id: film_id)
        raise FilmUnavailable, "Film is unavailable" unless film

        library_film = LibraryFilm.lock.find_by(user_id: user.id, film_id: film.id)
        if library_film.nil?
          LibraryFilmToWatch.create!(user:, film:)
        elsif library_film.can_add_to_watchlist?
          to_watch = library_film.becomes!(LibraryFilmToWatch)
          to_watch.save!
          to_watch
        else
          raise library_film.watchlist_addition_error
        end
      end
    end
  end
end
