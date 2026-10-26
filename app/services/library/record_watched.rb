module Library
  class RecordWatched
    def self.call(user_id:, library_film_id:)
      LibraryFilm.transaction(requires_new: true) do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable unless user&.active?

        library_film = LibraryFilm.lock.find_by(user_id: user.id, id: library_film_id)
        raise FilmUnavailable unless library_film
        raise AlreadyWatched unless library_film.can_watch?

        library_film = library_film.becomes!(LibraryFilmWatched)
        library_film.save!
        library_film.publish_event!(name: Events::FILM_MARKED_WATCHED)
        library_film
      end
    end
  end
end
