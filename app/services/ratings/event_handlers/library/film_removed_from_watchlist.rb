module Ratings
  module EventHandlers
    module Library
      class FilmRemovedFromWatchlist
        def self.call(rating_film:, user:, film:)
          return :ignored unless rating_film&.can_release_hold?

          rating_film.release_hold!
          :processed
        end
      end
    end
  end
end
