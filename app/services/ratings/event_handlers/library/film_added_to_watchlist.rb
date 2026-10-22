module Ratings
  module EventHandlers
    module Library
      class FilmAddedToWatchlist
        def self.call(rating_film:, user:, film:)
          rating_film ||= RatingFilm.create!(user:, film:)
          return :ignored unless rating_film.can_hold?

          rating_film.hold!
          :processed
        end
      end
    end
  end
end
