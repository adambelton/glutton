module Views
  module Community
    class NewReport < ::Views::Base
      def initialize(report:, evidence:, revision:, reasons:, form_path:, return_path:)
        @report, @evidence, @reasons = report, evidence, reasons
        @revision = revision
        @form_path, @return_path = form_path, return_path
      end

      def view_template
        page(title: t("community.reports.form_title"), narrow: true, class: "community-report-page") do
          errors(@report.errors.full_messages)
          form_with(url: @form_path, method: :post, class: "community-report-form", data: form_validation) do
            input(type: "hidden", name: "report[revision]", value: @revision)
            section(class: "community-report-section") do
              h2 { t("community.reports.reported_content") }
              render ::Community::ReportEvidence.new(evidence: @evidence)
            end
            div(class: "ui-field") do
              label(for: "report_reason") { t("community.reports.reason") }
              select(id: "report_reason", name: "report[reason]", class: "ui-input px-3 py-2", required: true) do
                option(value: "") { t("community.reports.choose_reason") }
                @reasons.each do |reason|
                  option(value: reason, selected: @report.reason == reason) { t("community.reports.reasons.#{reason}") }
                end
              end
            end
            div(class: "ui-field") do
              label(for: "report_explanation") { t("community.reports.optional_explanation") }
              textarea(id: "report_explanation", name: "report[explanation]", class: "ui-input",
                maxlength: ::Community::Report::EXPLANATION_LIMIT) { @report.explanation.to_s }
            end
            render Shared::ActionRow.new(full_width: true) do
              render RubyUI::Link.new(href: @return_path, variant: :ghost, class: "ui-action-button") { t("community.curations.cancel") }
              validated_submit(t("community.reports.submit"), class_name: "ui-action-button")
            end
          end
        end
      end
    end
  end
end
