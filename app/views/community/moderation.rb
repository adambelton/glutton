module Views
  module Community
    class Moderation < ::Views::Base
      def initialize(reports_page:, state:)
        @reports_page, @state = reports_page, state
      end

      def view_template
        page(title: t("community.moderation.title"), heading_outside_card: true,
          back_to: community_path, back_label: t("community.moderation.back")) do
          render Shared::NavigationTabs.new(label: t("community.reports.queue"), css_class: "mb-4 border-b") do
            ::Community::Reporting::BrowseReports::STATES.each_key do |state|
              a(href: community_moderation_path(state:), aria: { current: ("page" if @state == state) }) do
                t("community.reports.queues.#{state}")
              end
            end
          end
          if @reports_page.entries.empty?
            p(class: "ui-empty") { t("community.reports.empty.#{@state}") }
          else
            render ::Community::ReportTable.new(reports: @reports_page.entries, resolved: @state == "resolved")
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
            text_link(t("community.pagination.previous"), community_moderation_path(state: (@state if @state != "open"), page: number - 1), rel: "prev")
          end
          span { t("ui.search.pagination.page", number:, total:) }
          if number < total
            text_link(t("community.pagination.next"), community_moderation_path(state: (@state if @state != "open"), page: number + 1), rel: "next")
          end
        end
      end
    end
  end
end
