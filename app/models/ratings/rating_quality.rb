module Ratings
  class RatingQuality < ApplicationRecord
    module Classifications
      UNEXPRESSED = "unexpressed".freeze
      IMPLICITLY_EXPRESSED = "implicitly_expressed".freeze
      EXPLICITLY_EXPRESSED = "explicitly_expressed".freeze

      ALL = [ UNEXPRESSED, IMPLICITLY_EXPRESSED, EXPLICITLY_EXPRESSED ].freeze
    end

    def self.score_weights
      JSON.parse(Rails.root.join("config/ratings/quality_scores.json").read)
    end

    belongs_to :rating
    belongs_to :rating_quality_eval
    belongs_to :quality, class_name: "Registry::Quality"

    validates :classification, inclusion: { in: Classifications::ALL }
    validates :score, numericality: { only_integer: true }
  end
end
