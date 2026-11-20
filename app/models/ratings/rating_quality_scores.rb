module Ratings
  module RatingQualityScores
    UNEXPRESSED = {
      Rating::Values::BRILLIANT => 2,
      Rating::Values::PRETTY_GOOD => 1,
      Rating::Values::NOT_FOR_ME => -1,
      Rating::Values::GARBAGE => -2
    }.freeze

    def self.film_reaction(rating_value)
      UNEXPRESSED.fetch(rating_value).positive? ? "liked" : "disliked"
    end

    def self.for(rating_value:, direct:, inferred:)
      baseline = UNEXPRESSED.fetch(rating_value)
      sign = baseline <=> 0
      classifications = RatingQuality::Classifications

      case direct
      when "reinforces" then [ classifications::EXPLICITLY_EXPRESSED, 5 * sign ]
      when "exception" then [ classifications::EXPLICITLY_EXPRESSED, -5 * sign ]
      when "ruled_out" then [ classifications::EXPLICITLY_EXPRESSED, 0 ]
      when "praises_execution" then [ classifications::IMPLICITLY_EXPRESSED, 3 ]
      when "criticises_execution" then [ classifications::IMPLICITLY_EXPRESSED, 0 ]
      else
        return [ classifications::IMPLICITLY_EXPRESSED, inferred == "reinforces" ? 3 * sign : 0 ] if inferred.present?

        [ classifications::UNEXPRESSED, baseline ]
      end
    end
  end
end
