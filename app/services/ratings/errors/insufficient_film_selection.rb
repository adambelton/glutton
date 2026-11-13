module Ratings
  module Errors
    class InsufficientFilmSelection < StandardError
      def message
        I18n.t("ratings.onboarding.selection_required", count: CandidateSelection::InitialRatingFilmSelection::MINIMUM_FILMS)
      end
    end
  end
end
