module Ratings
  module Errors
    class HoldUnavailable < StandardError
      def message
        I18n.t("ratings.errors.hold_unavailable")
      end
    end
  end
end
