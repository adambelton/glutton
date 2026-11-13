module Recommendations
  module CandidateSelection
    class RecommendationUnlock
      def self.unlocked?(user:)
        return true if RecommendationFilm.where(user:).eligible.exists?

        minimum = NextCandidate::MINIMUM_ASSESSED_FILMS
        NextCandidate.current_quality_scores(user:).distinct.limit(minimum).pluck(:rating_id).size >= minimum
      end
    end
  end
end
