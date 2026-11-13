module Ratings
  module Errors
    class InitialRatingFilmSelectionUnavailable < StandardError
      def message
        I18n.t("ratings.onboarding.unavailable")
      end
    end
  end
end
