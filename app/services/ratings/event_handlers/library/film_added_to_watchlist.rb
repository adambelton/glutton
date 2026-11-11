module Ratings
  module EventHandlers
    module Library
      class FilmAddedToWatchlist
        def self.call(rating_film:, user:, film:)
          rating_film ||= RatingFilm.create!(user:, film:)
          return :ignored unless rating_film.can_suppress?

          rating_film.suppress!
          :processed
        end
      end
    end
  end
end
