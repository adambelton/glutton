module Library
  module EventHandlers
    module Recommendations
      class RecommendationAccepted
        def self.call(event:, user:)
          library_film = CollectionManagement::FindOrBuildLibraryFilm.call(user:, film_id: event.payload.fetch("film_id"))
          return :ignored unless library_film&.can_add_to_watchlist?

          library_film.add_to_watchlist!(correlation_id: event.correlation_id, causation_id: event.id)
          :processed
        end
      end
    end
  end
end
