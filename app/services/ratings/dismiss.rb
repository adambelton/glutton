module Ratings
  class Dismiss
    def self.call(user_id:, rating_film_id:)
      RatingFilm.transaction(requires_new: true) do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable unless user&.active?

        rating_film = RatingFilm.lock.find_by(id: rating_film_id, user_id: user.id)
        raise FilmUnavailable unless rating_film

        rating_film.dismiss!
      end
    end
  end
end
