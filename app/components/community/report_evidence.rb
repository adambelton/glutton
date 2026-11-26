module Community
  class ReportEvidence < Shared::Base
    ATTRIBUTE_ORDER = %w[title description additional_description body].freeze

    def initialize(evidence:)
      @evidence = evidence
    end

    def view_template
      dl(class: "community-report-evidence") do
        @evidence.sort_by { |attribute, _| ATTRIBUTE_ORDER.index(attribute) || ATTRIBUTE_ORDER.size }.each do |attribute, text|
          div(class: "community-report-excerpt") do
            dt { t("community.reports.evidence_attributes.#{attribute}") }
            dd(class: "community-curation-prompt") { text }
          end
        end
      end
    end
  end
end
