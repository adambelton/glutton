module Recommendations
  module EventHandlers
    module Library
      class FilmRemovedFromWatchlist
        def self.call(recommendation_film:)
          recommendation_film.release_suppression!
        end
      end
    end
  end
end
