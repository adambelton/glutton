module Ratings
  module Errors
    class SuppressionUnavailable < StandardError
      def message
        I18n.t("ratings.errors.suppression_unavailable")
      end
    end
  end
end
