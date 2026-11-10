module Ratings
  class ReviseRating
    def self.call(user_id:, rating_film_id:, previous_rating_id:, value:, notes: nil)
      Rating.transaction(requires_new: true) do
        user = Identity::User.lock.find_by(id: user_id)
        raise IdentityUnavailable unless user&.active?

        rating_film = RatingFilm.lock.find_by(id: rating_film_id, user_id: user.id)
        raise FilmUnavailable unless rating_film

        rating = rating_film.revise_rating!(previous_rating_id:, value:, notes:)
        AssessRatingQualitiesJob.enqueue!(rating.id)
        rating
      end
    end
  end
end
