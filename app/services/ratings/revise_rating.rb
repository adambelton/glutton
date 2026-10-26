module Ratings
  class ReviseRating
    def self.call(user_id:, rating_film_id:, previous_rating_id:, value:, expression_texts: [])
      Rating.transaction(requires_new: true) do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable unless user&.active?

        rating_film = RatingFilm.lock.find_by(id: rating_film_id, user_id: user.id)
        raise FilmUnavailable unless rating_film

        rating_film.revise_rating!(previous_rating_id:, value:, expression_texts:)
      end
    end
  end
end
