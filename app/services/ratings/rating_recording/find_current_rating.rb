module Ratings
  module RatingRecording
    class FindCurrentRating
      def self.call(user_id:, film_id:)
        RatingFilm.transaction(requires_new: true) do
          user = Identity::User.lock.find_by(id: user_id)
          raise Identity::Errors::Unavailable unless user&.active?

          rating_film = RatingFilm.find_by(user_id: user.id, film_id:)
          raise Ratings::Errors::FilmUnavailable unless rating_film

          rating_film.current_rating || raise(Errors::RevisionUnavailable)
        end
      end
    end
  end
end
