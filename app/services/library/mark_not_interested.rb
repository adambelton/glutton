module Library
  class MarkNotInterested
    def self.call(user_id:, film_id:)
      LibraryFilm.transaction do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable, "An active identity is required" unless user&.active?

        film = Film.find_by(id: film_id)
        raise FilmUnavailable, "Film is unavailable" unless film

        library_film = LibraryFilm.lock.find_by(user_id: user.id, film_id: film.id)
        if library_film.nil?
          LibraryFilmNotInterested.create!(user:, film:)
        elsif library_film.can_mark_not_interested?
          not_interested = library_film.becomes!(LibraryFilmNotInterested)
          not_interested.save!
          not_interested
        else
          raise library_film.dismissal_error
        end
      end
    end
  end
end
