module Recommendations
  module CandidateSelection
    class RecommendationUnlock
      def self.unlocked?(user:)
        return true if RecommendationFilm.where(user:).eligible.exists?

        minimum = NextCandidate::MINIMUM_ASSESSED_FILMS
        ::Ratings::RatingQuality.current_rating_qualities_for_user(user_id: user.id).distinct.limit(minimum).pluck(:rating_id).size >= minimum
      end
    end
  end
end
