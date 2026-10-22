module Ratings
  class SubmitRating
    def self.call(user_id:, rating_film_id:, value:, expression_texts: [])
      Rating.transaction(requires_new: true) do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable unless user&.active?

        rating_film = RatingFilm.lock.find_by(id: rating_film_id, user_id: user.id)
        raise FilmUnavailable unless rating_film

        rating = rating_film.submit_rating!(value:, expression_texts:)
        rating.publish_event!
        rating
      end
    end
  end
end
