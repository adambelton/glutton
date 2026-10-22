module Library
  class MarkNotInterested
    def self.call(user_id:, film_id:)
      LibraryFilm.transaction(requires_new: true) do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable, "An active identity is required" unless user&.active?

        film = Film.find_by(id: film_id)
        raise FilmUnavailable, "Film is unavailable" unless film

        library_film = LibraryFilm.lock.find_by(user_id: user.id, film_id: film.id)
        if library_film.nil?
          library_film = LibraryFilmNotInterested.create!(user:, film:)
        elsif library_film.can_mark_not_interested?
          library_film = library_film.becomes!(LibraryFilmNotInterested)
          library_film.save!
        else
          raise library_film.dismissal_error
        end
        library_film.publish_event!(name: Events::FILM_MARKED_NOT_INTERESTED)
        library_film
      end
    end
  end
end
