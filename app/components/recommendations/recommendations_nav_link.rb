module Recommendations
  class RecommendationsNavLink < Shared::Base
    def initialize(user:)
      @user = user
    end

    def view_template
      if CandidateSelection::RecommendationUnlock.unlocked?(user: @user)
        a(href: recommendation_path) { t("recommendations.title") }
      else
        tooltip = t("recommendations.navigation_locked", required: CandidateSelection::NextCandidate::MINIMUM_ASSESSED_FILMS)
        span(class: "recommendations-nav-lock", role: "link", tabindex: "0",
          aria: { disabled: "true", describedby: "recommendations-nav-tooltip" }) do
          plain t("recommendations.title")
          svg(viewBox: "0 0 24 24", width: "14", height: "14", fill: "none", stroke: "currentColor",
            stroke_width: "2", aria: { hidden: true }) do |icon|
            icon.rect(x: "5", y: "10", width: "14", height: "11", rx: "2")
            icon.path(d: "M8 10V7a4 4 0 0 1 8 0v3")
          end
          span(id: "recommendations-nav-tooltip", role: "tooltip") { tooltip }
        end
      end
    end
  end
end
