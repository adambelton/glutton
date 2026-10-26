module Ratings
  class FindCurrentRating
    def self.call(user_id:, film_id:)
      RatingFilm.transaction(requires_new: true) do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable unless user&.active?

        rating_film = RatingFilm.find_by(user_id: user.id, film_id:)
        raise FilmUnavailable unless rating_film

        rating_film.current_rating || raise(RevisionUnavailable)
      end
    end
  end
end
