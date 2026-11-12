module Ratings
  module EventHandlers
    module Library
      class FilmRemovedFromLibrary
        def self.call(rating_film:, user:, film:)
          rating_film ||= RatingFilm.new(user:, film:)
          return :ignored unless rating_film.can_suppress?

          rating_film.suppress!
          :processed
        end
      end
    end
  end
end
