module Ratings
  module CandidateSelection
    class PrepareCandidate
      def self.call(user_id:, film_id:)
        RatingFilm.transaction(requires_new: true) do
          user = Identity::User.lock.find_by(id: user_id)
          raise Identity::Errors::Unavailable unless user&.active?

          film = Registry::Film.find_by(id: film_id)
          raise Ratings::Errors::FilmUnavailable unless film

          rating_film = RatingFilm.find_or_create_by!(user:, film:)
          raise Ratings::Errors::AlreadyRated unless rating_film.can_submit_rating?

          ActivityMonitoring.current_operation_span&.set_operation(ActivityMonitoring::Operations::CREATE_RATING_FILM) if rating_film.previously_new_record?
          rating_film
        end
      end
    end
  end
end
