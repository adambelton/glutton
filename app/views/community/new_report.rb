module Views
  module Community
    class NewReport < ::Views::Base
      def initialize(report:, parts:, revisions:, reasons:, form_path:, return_path:)
        @report, @parts, @reasons = report, parts, reasons
        @revisions = revisions
        @form_path, @return_path = form_path, return_path
      end

      def view_template
        page(title: t("community.reports.form_title"), narrow: true) do
          errors(@report.errors.full_messages)
          form_with(url: @form_path, method: :post, data: form_validation) do
            part_field
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

      private

      def part_field
        @revisions.each do |part, revision|
          input(type: "hidden", name: "report[revisions][#{part}]", value: revision)
        end

        if @parts.one?
          input(type: "hidden", name: "report[part]", value: @parts.keys.first)
          p(class: "community-curation-prompt") { @parts.values.first }
        else
          fieldset(class: "ui-field") do
            legend { t("community.reports.part") }
            @parts.each do |part, text|
              label(class: "community-report-option") do
                input(type: "radio", name: "report[part]", value: part, required: true, checked: @report.part == part)
                strong { t("community.reports.parts.#{part}") }
                span(class: "community-curation-prompt") { text }
              end
            end
          end
        end
      end
    end
  end
end
