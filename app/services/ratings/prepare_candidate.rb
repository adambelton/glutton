module Ratings
  class PrepareCandidate
    def self.call(user_id:, film_id:)
      RatingFilm.transaction(requires_new: true) do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable unless user&.active?

        film = Film.find_by(id: film_id)
        raise FilmUnavailable unless film

        rating_film = RatingFilm.find_or_create_by!(user:, film:)
        raise AlreadyRated unless rating_film.can_submit_rating?

        rating_film
      end
    end
  end
end
