module Recommendations
  module EventHandlers
    module Library
      class FilmMarkedWatched
        def self.call(recommendation_film:)
          recommendation_film.suppress!
        end
      end
    end
  end
end
