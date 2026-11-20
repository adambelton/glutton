module Recommendations
  module CandidateSelection
    class CalculateRecommendationMatch
      MIDPOINT = 50
      SCALE = 180
      MINIMUM_SUPPORTED_QUALITIES = 5
      MINIMUM_RATINGS_PER_QUALITY = 3
      MINIMUM_CONTRIBUTING_RATINGS = 8
      MINIMUM_COVERAGE = Rational(3, 5)

      def self.call(quality_ids:, rating_scores:, points: nil)
        return if quality_ids.size < MINIMUM_SUPPORTED_QUALITIES

        matched_scores = rating_scores.select { |_, quality_id, _| quality_ids.include?(quality_id) }
        supported_qualities = matched_scores.reject { |_, _, score| score.zero? }.group_by { |_, quality_id, _| quality_id }
          .values.select { |scores| scores.map(&:first).uniq.size >= MINIMUM_RATINGS_PER_QUALITY }
        return if supported_qualities.size < MINIMUM_SUPPORTED_QUALITIES ||
          Rational(supported_qualities.size, quality_ids.size) < MINIMUM_COVERAGE

        contributing_ratings = supported_qualities.flat_map { |scores| scores.map(&:first) }.uniq
        return if contributing_ratings.size < MINIMUM_CONTRIBUTING_RATINGS

        points ||= matched_scores.sum(&:last)
        return MIDPOINT if points.zero?

        percent = MIDPOINT + Rational(MIDPOINT * points, points.abs + SCALE)
        points.positive? ? percent.round.clamp(51, 99) : percent.round.clamp(1, 49)
      end
    end
  end
end
