module Shared
  class ProfileQualityExpansionItem < Base
    def initialize(quality:)
      @quality = quality
    end

    def view_template
      details(class: "profile-quality-item") do
        summary do
          span(class: "profile-quality-name") { @quality.fetch(:name) }
          span(class: "profile-quality-score") { "%+d" % @quality.fetch(:score) }
        end
        p { @quality.fetch(:definition).presence || t("account.quality_rankings.definition_unavailable") }
      end
    end
  end
end
