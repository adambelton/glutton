module Library
  module EventHandlers
    module Recommendations
      class RecommendationAccepted
        def self.call(event:, user:)
          library_film = CollectionManagement::FindOrBuildLibraryFilm.call(user:, film_id: event.payload.fetch("film_id"))
          return :ignored unless library_film.present?

          library_film.add_to_watchlist_from_event!(correlation_id: event.correlation_id, causation_id: event.id)
        end
      end
    end
  end
end
