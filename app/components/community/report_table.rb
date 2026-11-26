module Community
  class ReportTable < Shared::Base
    def initialize(reports:, resolved:)
      @reports, @resolved = reports, resolved
    end

    def view_template
      caption = t("community.reports.queue")
      render RubyUI::Table.new(scroll_label: caption, class: "ui-collection-table community-report-table") do
        render RubyUI::TableCaption.new(class: "sr-only") { caption }
        render RubyUI::TableHeader.new do
          render RubyUI::TableRow.new do
            columns.each do |column|
              render Shared::TableCell.new(heading: true) { t("community.reports.#{column}") }
            end
          end
        end
        render RubyUI::TableBody.new do
          @reports.each { |report| row(report) }
        end
      end
    end

    private

    def columns
      if @resolved
        %w[table.identifier reason resolution.outcome resolution.action_taken submitted_at resolution.reviewed_at]
      else
        %w[table.identifier reportable.type reason table.priority submitted_at]
      end
    end

    def row(report)
      render RubyUI::TableRow.new do
        render Shared::TableCell.new do
          a(href: community_moderation_report_path(report), class: "font-semibold hover:underline hover:text-primary") do
            t("community.reports.identifier", id: report.id)
          end
        end
        unless @resolved
          render Shared::TableCell.new { report.reportable_type || t("community.reports.unavailable") }
        end
        render Shared::TableCell.new { t("community.reports.reasons.#{report.reason}") }
        if @resolved
          render Shared::TableCell.new { t("community.reports.resolution.outcomes.#{report.resolution_outcome}") }
          render Shared::TableCell.new { render ReportResolutionAction.new(report:) if report.accepted? }
        else
          render Shared::TableCell.new do
            t(report.high_priority? ? "community.reports.high_priority" : "community.reports.table.normal_priority")
          end
        end
        render Shared::TableCell.new { timestamp(report.created_at) }
        render Shared::TableCell.new { timestamp(report.resolved_at) } if @resolved
      end
    end

    def timestamp(value)
      time(datetime: value.iso8601) { I18n.l(value, format: :long) }
    end
  end
end
