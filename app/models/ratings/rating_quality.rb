module Ratings
  class RatingQuality < ApplicationRecord
    module Classifications
      UNEXPRESSED = "unexpressed".freeze
      IMPLICITLY_EXPRESSED = "implicitly_expressed".freeze
      EXPLICITLY_EXPRESSED = "explicitly_expressed".freeze

      ALL = [ UNEXPRESSED, IMPLICITLY_EXPRESSED, EXPLICITLY_EXPRESSED ].freeze
    end

    SCORE_WEIGHTS = {
      Classifications::UNEXPRESSED => {
        "brilliant" => 2, "pretty_good" => 1, "not_for_me" => -1, "garbage" => -2
      }.freeze,
      Classifications::EXPLICITLY_EXPRESSED => {
        "brilliant" => 5, "pretty_good" => 3, "not_for_me" => -3, "garbage" => -5
      }.freeze
    }.freeze

    belongs_to :rating
    belongs_to :rating_quality_eval
    belongs_to :quality, class_name: "Registry::Quality"

    validates :classification, inclusion: { in: Classifications::ALL }
    validates :score, numericality: { only_integer: true }
  end
end
