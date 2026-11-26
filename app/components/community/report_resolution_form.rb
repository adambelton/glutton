module Community
  class ReportResolutionForm < Shared::Base
    def initialize(report:, draft:)
      @report, @draft = report, draft
    end

    def view_template
      section(class: "community-report-resolution mt-8 border-t pt-6") do
        h2 { t("community.reports.resolution.title") }
        errors(@draft.errors.full_messages) if @draft.present?
        form_with(url: resolve_community_moderation_report_path(@report), method: :patch, class: "community-report-form", data: form_validation) do
          input(type: :hidden, name: "resolution[expected_status]", value: @report.status)
          outcome_field
          div(class: "ui-field") do
            label(for: "resolution_summary") { t("community.reports.resolution.summary") }
            p(id: "resolution-guidance", class: "community-report-guidance") { t("community.reports.resolution.guidance") }
            textarea(id: "resolution_summary", name: "resolution[summary]", class: "ui-input", required: true,
              aria: { describedby: "resolution-guidance resolution-retention-notice" }, maxlength: Report::RESOLUTION_SUMMARY_LIMIT) { @draft&.resolution_summary.to_s }
          end
          p(id: "resolution-retention-notice", class: "community-report-guidance") { t("community.reports.resolution.retention_notice") }
          validated_submit(t("community.reports.resolution.title"))
        end
      end
    end

    private

    def outcome_field
      div(class: "ui-field") do
        label(for: "resolution_outcome") { t("community.reports.resolution.outcome") }
        select(id: "resolution_outcome", name: "resolution[outcome]", class: "ui-input px-3 py-2", required: true) do
          option(value: "") { t("community.reports.resolution.choose_outcome") }
          Report::RESOLUTION_OUTCOMES.each do |outcome|
            option(value: outcome, selected: outcome == @draft&.resolution_outcome) do
              t("community.reports.resolution.outcomes.#{outcome}")
            end
          end
        end
      end
    end
  end
end
