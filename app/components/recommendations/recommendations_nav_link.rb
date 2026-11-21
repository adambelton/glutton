module Recommendations
  class RecommendationsNavLink < Shared::Base
    def initialize(unlocked:)
      @unlocked = unlocked
    end

    def view_template
      if @unlocked
        a(href: recommendation_path) { t("recommendations.title") }
      else
        tooltip = t("recommendations.navigation_locked", required: CandidateSelection::NextCandidate::MINIMUM_ASSESSED_FILMS)
        render Shared::LockedNavigationLink.new(label: t("recommendations.title"), tooltip:, tooltip_id: "recommendations-nav-tooltip",
          data: { recommendations_unlock_target: "lockedLink" })
      end
    end
  end
end
