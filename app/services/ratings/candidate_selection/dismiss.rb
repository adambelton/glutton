module Ratings
  module CandidateSelection
    class Dismiss
      def self.call(user_id:, rating_film_id:)
        RatingFilm.transaction(requires_new: true) do
          user = Identity::User.lock.find_by(id: user_id)
          raise Identity::Errors::Unavailable unless user&.active?

          rating_film = RatingFilm.lock.find_by(id: rating_film_id, user_id: user.id)
          raise Ratings::Errors::FilmUnavailable unless rating_film

          rating_film.dismiss!
        end
      end
    end
  end
end
