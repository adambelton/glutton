module Community
  class ReportResolutionForm < Shared::Base
    def initialize(report:, draft:)
      @report, @draft = report, draft
    end

    def view_template
      section(class: "community-report-resolution mt-8 border-t pt-6") do
        h2 { t("community.reports.resolution.title") }
        errors(@draft.errors.full_messages) if @draft.present?
        form_with(url: resolve_community_moderation_report_path(@report), method: :patch, class: "community-report-form",
          data: form_validation(controller: "report-resolution", action: "change->report-resolution#update",
            report_resolution_accepted_value: Report::ACCEPTED_OUTCOME)) do
          input(type: :hidden, name: "resolution[expected_status]", value: @report.status)
          input(type: :hidden, name: "resolution[revision]", value: @report.review_revision)
          div(class: "community-report-columns") do
            outcome_field
            action_field
          end
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
        select(id: "resolution_outcome", name: "resolution[outcome]", class: "ui-input px-3 py-2", required: true,
          data: { report_resolution_target: "outcome" }) do
          option(value: "", disabled: true, selected: !Report::RESOLUTION_OUTCOMES.include?(@draft&.resolution_outcome)) do
            t("community.reports.resolution.choose_outcome")
          end
          Report::RESOLUTION_OUTCOMES.each do |outcome|
            option(value: outcome, selected: outcome == @draft&.resolution_outcome) do
              t("community.reports.resolution.outcomes.#{outcome}")
            end
          end
        end
      end
    end

    def action_field
      accepted = @draft&.accepted? || false
      div(class: "ui-field") do
        label(for: "resolution_action") { t("community.reports.resolution.action_taken") }
        select(id: "resolution_action", name: "resolution[action]", class: "ui-input px-3 py-2", required: true, disabled: !accepted,
          data: { report_resolution_target: "action" }) do
          option(value: "") { t("community.reports.resolution.choose_action") }
          option(value: Report::NO_RESOLUTION_ACTION, selected: @draft&.selected_resolution_action == Report::NO_RESOLUTION_ACTION) do
            t("community.reports.resolution.actions.none")
          end
          reportable = @report.reportable
          reportable.report_deletion_actions.each { |action| deletion_option(reportable, action) } if reportable.present?
        end
      end
    end

    def deletion_option(reportable, action)
      option(value: action, selected: action == @draft&.selected_resolution_action) do
        if action == Reportable::DELETE_RECORD
          t("community.reports.resolution.delete_record.#{reportable.model_name.i18n_key}")
        else
          attribute = t("community.reports.evidence_attributes.#{action.delete_prefix(Reportable::DELETE_ATTRIBUTE_PREFIX)}")
          t("community.reports.resolution.delete_attribute", attribute:)
        end
      end
    end
  end
end
