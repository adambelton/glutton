module Ratings
  class QualityAssessmentFailed < StandardError
    attr_reader :reason

    def initialize(reason:)
      @reason = reason
      super("Rating quality assessment failed (#{reason})")
    end
  end
end
