module Account
  class TasteProfile < Shared::Base
    def initialize(profile:)
      @profile = profile
    end

    def view_template
      profile_content
      quality_rankings
    end

    private

    def quality_rankings
      rankings = @profile.fetch(:quality_rankings)
      div(class: "profile-quality-rankings") do
        quality_list(:top, rankings.fetch(:top))
        quality_list(:bottom, rankings.fetch(:bottom))
      end
    end

    def quality_list(kind, qualities)
      section(aria: { labelledby: "#{kind}-qualities-heading" }) do
        h3(id: "#{kind}-qualities-heading") { t("account.quality_rankings.#{kind}") }
        if qualities.empty?
          p { t("account.quality_rankings.#{kind}_empty") }
        else
          ul(class: "profile-quality-list", role: "list") do
            qualities.each { |quality| li { quality_item(quality) } }
          end
        end
      end
    end

    def quality_item(quality)
      definition = quality.fetch(:definition)
      details(class: "profile-quality-item") do
        summary do
          quality_heading(quality)
        end
        p { definition.presence || t("account.quality_rankings.definition_unavailable") }
      end
    end

    def quality_heading(quality)
      span(class: "profile-quality-name") { quality.fetch(:name) }
      span(class: "profile-quality-score") { "%+d" % quality.fetch(:score) }
    end

    def profile_content
      if @profile[:profile].present?
        div(class: "profile-narrative") { @profile.fetch(:profile) }
      else
        p { t("account.empty") }
      end
    end
  end
end
