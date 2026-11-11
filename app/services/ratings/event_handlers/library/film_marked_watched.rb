module Ratings
  module EventHandlers
    module Library
      class FilmMarkedWatched
        def self.call(rating_film:, user:, film:)
          if rating_film.nil?
            RatingFilm.create!(user:, film:)
          elsif rating_film.can_release_suppression?
            rating_film.release_suppression!
          else
            return :ignored
          end
          :processed
        end
      end
    end
  end
end
