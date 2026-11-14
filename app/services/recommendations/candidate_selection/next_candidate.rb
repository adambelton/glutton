module Recommendations
  module CandidateSelection
    class NextCandidate
      MINIMUM_ASSESSED_FILMS = 5
      Result = Data.define(:assessed_film_count, :minimum_assessed_films, :candidate, :film) do
        def unlocked?
          assessed_film_count >= minimum_assessed_films
        end
      end

      def self.call(user_id:, excluding_film_id: nil)
        user = Identity::User.find_by(id: user_id)
        raise Identity::Errors::Unavailable unless user&.active?

        current_rating_qualities = ::Ratings::RatingQuality.current_rating_qualities_for_user(user_id: user.id)
        scores = current_rating_qualities.pluck(:rating_id, :quality_id, :score)
        assessed_film_count = scores.map(&:first).uniq.size

        candidate = if assessed_film_count >= MINIMUM_ASSESSED_FILMS
          films = Registry::Film.where.not(id: RecommendationFilm.where(user:).select(:film_id))
          films = films.where.not(id: excluding_film_id) if excluding_film_id.present?
          film_ids = films.pluck(:id)
          quality_ids_by_film = Registry::FilmQuality.where(film_id: film_ids).pluck(:film_id, :quality_id)
            .group_by(&:first).transform_values { |rows| rows.map(&:last) }
          scores_by_quality = scores.each_with_object(Hash.new(0)) do |(_, quality_id, score), totals|
            totals[quality_id] += score
          end
          RankFilms.call(film_ids:, quality_ids_by_film:, scores_by_quality:)
        end

        film = Registry::Film.find_by(id: candidate.film_id) if candidate.present?
        candidate = nil unless film.present?
        Result.new(assessed_film_count:, minimum_assessed_films: MINIMUM_ASSESSED_FILMS, candidate:, film:)
      end
    end
  end
end
