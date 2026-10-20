module Library
  class RecordWatched
    def self.call(user:, film:)
      raise IdentityUnavailable, "An active identity is required" unless user&.persisted?

      LibraryFilm.transaction do
        fresh_user = User.lock.find_by(id: user.id)
        raise IdentityUnavailable, "An active identity is required" unless fresh_user&.active?
        raise FilmUnavailable, "Film is unavailable" unless film&.persisted? && Film.exists?(film.id)

        LibraryFilm.lock.find_by(user_id: fresh_user.id, film_id: film.id) ||
          LibraryFilmWatched.create!(user: fresh_user, film_id: film.id)
      end
    end
  end
end
