module Ratings
  module Errors
    class SuppressionReleaseUnavailable < StandardError
      def message
        I18n.t("ratings.errors.suppression_release_unavailable")
      end
    end
  end
end
