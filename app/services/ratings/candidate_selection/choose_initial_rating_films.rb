module Ratings
  module CandidateSelection
    class ChooseInitialRatingFilms
      extend Monitoring::Instrumentation
      instrument_class_operations :queue!

      def self.queue!(user_id:, film_ids:)
        RatingFilm.transaction(requires_new: true) do
          user = Identity::User.lock.find_by(id: user_id)
          raise Identity::Errors::Unavailable unless user&.active?

          InitialRatingFilmSelection.queue!(user:, film_ids:) do |selected_film_ids|
            Registry::Film.where(id: selected_film_ids).count == selected_film_ids.size
          end
        end
      end
    end
  end
end
