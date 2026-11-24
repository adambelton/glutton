module Ratings
  module CandidateSelection
    class ChooseInitialRatingFilms
      extend Monitoring::Instrumentation
      instrument_class_operations :queue!

      def self.queue!(user_id:, film_ids:)
        InitialRatingFilmSelection.queue!(user_id:, film_ids:) do |selected_film_ids|
          Registry::Film.where(id: selected_film_ids).count == selected_film_ids.size
        end
      end
    end
  end
end
