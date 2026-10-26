module Library
  class RemoveNotInterested
    def self.call(user_id:, library_film_id:)
      LibraryFilm.transaction(requires_new: true) do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable unless user&.active?

        library_film = LibraryFilm.lock.find_by(user_id: user.id, id: library_film_id)
        raise FilmUnavailable unless library_film
        raise NotMarkedNotInterested unless library_film.can_remove_from_not_interested?

        library_film.destroy!
        library_film.publish_event!(name: Events::FILM_DISMISSAL_REMOVED)
        library_film
      end
    end
  end
end
