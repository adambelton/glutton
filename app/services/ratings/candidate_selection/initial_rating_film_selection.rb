module Ratings
  module CandidateSelection
    class InitialRatingFilmSelection
      MINIMUM_FILMS = 5

      def self.available?(user:)
        !RatingFilm.exists?(user:)
      end

      def self.queue!(user_id:, film_ids:)
        RatingFilm.transaction(requires_new: true) do
          user = Identity::User.lock.find_by(id: user_id)
          raise Identity::Errors::Unavailable unless user&.active?
          raise Errors::InitialRatingFilmSelectionUnavailable unless available?(user:)

          film_ids = film_ids.uniq
          raise Errors::InsufficientFilmSelection if film_ids.size < MINIMUM_FILMS
          raise Errors::FilmUnavailable unless yield(film_ids)

          film_ids.each { |film_id| RatingFilm.create!(user:, film_id:) }
        end
      end
    end
  end
end
