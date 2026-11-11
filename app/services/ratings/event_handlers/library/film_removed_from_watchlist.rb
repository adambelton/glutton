module Ratings
  module EventHandlers
    module Library
      class FilmRemovedFromWatchlist
        def self.call(rating_film:, user:, film:)
          return :ignored unless rating_film&.can_release_suppression?

          rating_film.release_suppression!
          :processed
        end
      end
    end
  end
end
