module Recommendations
  module EventHandlers
    module Library
      class FilmRemovedFromWatchlist
        def self.call(recommendation_film:)
          recommendation_film.discard_suppression_only_record!
        end
      end
    end
  end
end
