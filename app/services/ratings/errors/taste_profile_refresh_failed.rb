module Ratings
  module Errors
    class TasteProfileRefreshFailed < StandardError
      attr_reader :reason

      def initialize(reason:)
        @reason = reason
        super("Taste profile refresh failed (#{reason})")
      end
    end
  end
end
