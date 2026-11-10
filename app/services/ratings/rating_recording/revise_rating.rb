module Ratings
  module RatingRecording
    class ReviseRating
      def self.call(user_id:, rating_film_id:, previous_rating_id:, value:, notes: nil)
        Rating.transaction(requires_new: true) do
          user = Identity::User.lock.find_by(id: user_id)
          raise Identity::Errors::Unavailable unless user&.active?

          rating_film = RatingFilm.lock.find_by(id: rating_film_id, user_id: user.id)
          raise Ratings::Errors::FilmUnavailable unless rating_film

          rating = rating_film.revise_rating!(previous_rating_id:, value:, notes:)
          AssessRatingQualitiesJob.enqueue!(rating.id)
          rating
        end
      end
    end
  end
end
