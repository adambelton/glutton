module Views
  module Community
    class Moderation < ::Views::Base
      def initialize(reports_page:)
        @reports_page = reports_page
      end

      def view_template
        page(title: t("community.moderation.title"), heading_outside_card: true,
          back_to: community_path, back_label: t("community.moderation.back")) do
          if @reports_page.entries.empty?
            p(class: "ui-empty") { t("community.reports.empty") }
          else
            ul(class: "ui-divided-list") do
              @reports_page.entries.each do |report|
                li(class: "py-2 flex flex-wrap items-baseline gap-x-3") do
                  text_link(t("community.reports.identifier", id: report.id), community_moderation_report_path(report))
                  span { t("community.reports.reasons.#{report.reason}") }
                  span { t("community.reports.high_priority") } if report.high_priority?
                  span { t("community.reports.states.#{report.status}") }
                  span(class: "muted") { I18n.l(report.created_at, format: :long) }
                end
              end
            end
            pagination
          end
        end
      end

      private

      def pagination
        number = @reports_page.number
        total = @reports_page.total_pages
        return if total == 1

        nav(class: "community-board-pagination", aria: { label: t("community.reports.pagination") }) do
          if number > 1
            text_link(t("community.pagination.previous"), community_moderation_path(page: number - 1), rel: "prev")
          end
          span { t("ui.search.pagination.page", number:, total:) }
          if number < total
            text_link(t("community.pagination.next"), community_moderation_path(page: number + 1), rel: "next")
          end
        end
      end
    end
  end
end
