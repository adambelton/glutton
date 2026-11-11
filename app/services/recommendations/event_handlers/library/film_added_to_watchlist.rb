module Recommendations
  module EventHandlers
    module Library
      class FilmAddedToWatchlist
        def self.call(recommendation_film:)
          recommendation_film.suppress!
        end
      end
    end
  end
end
