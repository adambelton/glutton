module Recommendations
  module CandidateSelection
    class NextRecommendation
      Result = Data.define(:recommendation_film, :assessed_film_count, :minimum_assessed_films) do
        def unlocked?
          recommendation_film.present? || assessed_film_count >= minimum_assessed_films
        end
      end

      def self.call(user_id:, excluding_film_id: nil)
        RecommendationFilm.transaction(requires_new: true) do
          user = Identity::User.lock.find_by(id: user_id)
          raise Identity::Errors::Unavailable unless user&.active?

          queue = RecommendationFilm.where(user:).eligible
          queue = queue.where.not(film_id: excluding_film_id) if excluding_film_id.present?
          recommendation_film = queue.includes(:film).order(:recommended_at, :id).first
          minimum = NextCandidate::MINIMUM_ASSESSED_FILMS
          if recommendation_film.present?
            next Result.new(recommendation_film:, assessed_film_count: nil, minimum_assessed_films: minimum)
          end

          ranking = NextCandidate.call(user_id: user.id, excluding_film_id:)
          if ranking.film.present?
            recommendation_film = RecommendationFilm.create!(user:, film: ranking.film, recommended_at: Time.current)
          end

          Result.new(recommendation_film:, assessed_film_count: ranking.assessed_film_count, minimum_assessed_films: minimum)
        end
      end
    end
  end
end
