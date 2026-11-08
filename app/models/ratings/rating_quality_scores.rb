module Ratings
  module RatingQualityScores
    UNEXPRESSED = {
      Rating::Values::BRILLIANT => 2,
      Rating::Values::PRETTY_GOOD => 1,
      Rating::Values::NOT_FOR_ME => -1,
      Rating::Values::GARBAGE => -2
    }.freeze

    IMPLICITLY_EXPRESSED = {
      Rating::Values::BRILLIANT => 4,
      Rating::Values::PRETTY_GOOD => 2,
      Rating::Values::NOT_FOR_ME => -2,
      Rating::Values::GARBAGE => -4
    }.freeze

    EXPLICITLY_EXPRESSED = {
      Rating::Values::BRILLIANT => 5,
      Rating::Values::PRETTY_GOOD => 3,
      Rating::Values::NOT_FOR_ME => -3,
      Rating::Values::GARBAGE => -5
    }.freeze

    ALL = {
      RatingQuality::Classifications::UNEXPRESSED => UNEXPRESSED,
      RatingQuality::Classifications::IMPLICITLY_EXPRESSED => IMPLICITLY_EXPRESSED,
      RatingQuality::Classifications::EXPLICITLY_EXPRESSED => EXPLICITLY_EXPRESSED
    }.freeze
  end
end
