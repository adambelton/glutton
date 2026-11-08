module Ratings
  class ExpressionProfileRefreshFailed < StandardError
    attr_reader :reason

    def initialize(reason:)
      @reason = reason
      super("Expression profile refresh failed (#{reason})")
    end
  end
end
