module Library
  class RemoveNotInterested
    def self.call(user_id:, film_id:)
      LibraryFilm.transaction(requires_new: true) do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable, "An active identity is required" unless user&.active?

        film = Film.find_by(id: film_id)
        raise FilmUnavailable, "Film is unavailable" unless film

        library_film = LibraryFilmNotInterested.lock.find_by(user_id: user.id, film_id: film.id)
        raise NotMarkedNotInterested, "Film is not marked not interested" unless library_film

        library_film.destroy!
        library_film.publish_event!(name: Events::FILM_DISMISSAL_REMOVED)
        library_film
      end
    end
  end
end
