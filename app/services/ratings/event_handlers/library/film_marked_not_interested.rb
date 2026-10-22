module Ratings
  module EventHandlers
    module Library
      class FilmMarkedNotInterested
        def self.call(rating_film:, user:, film:)
          rating_film ||= RatingFilm.create!(user:, film:)
          changed = false
          if rating_film.can_dismiss?
            rating_film.dismiss!
            changed = true
          end
          if rating_film.can_release_hold?
            rating_film.release_hold!
            changed = true
          end
          changed ? :processed : :ignored
        end
      end
    end
  end
end
