module Library
  module EventHandlers
    module Ratings
      class RatingSubmitted
        def self.call(event:, user:)
          library_film = CollectionManagement::FindOrBuildLibraryFilm.call(user:, film_id: event.payload.fetch("film_id"))
          if library_film&.can_move_to_watched?
            library_film.move_to_watched!(correlation_id: event.correlation_id, causation_id: event.id)
          elsif library_film&.can_add_to_watched?
            library_film.add_to_watched!(correlation_id: event.correlation_id, causation_id: event.id)
          else
            return :ignored
          end
          :processed
        end
      end
    end
  end
end
