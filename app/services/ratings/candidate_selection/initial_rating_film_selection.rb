module Ratings
  module CandidateSelection
    class InitialRatingFilmSelection
      MINIMUM_FILMS = 5

      def self.available?(user:)
        !RatingFilm.exists?(user:)
      end

      # The caller must hold the active account's row lock through this operation.
      def self.queue!(user:, film_ids:)
        raise Errors::InitialRatingFilmSelectionUnavailable unless available?(user:)

        film_ids = film_ids.uniq
        raise Errors::InsufficientFilmSelection if film_ids.size < MINIMUM_FILMS
        raise Errors::FilmUnavailable unless yield(film_ids)

        film_ids.each { |film_id| RatingFilm.create!(user:, film_id:) }
      end
    end
  end
end
