module Views
  module Community
    class Moderation < ::Views::Base
      def initialize(queue_page:, state:)
        @queue_page, @state = queue_page, state
      end

      def view_template
        page(title: t("community.moderation.title"), heading_outside_card: true,
          back_to: community_path, back_label: t("community.moderation.back")) do
          render Shared::NavigationTabs.new(label: t("community.moderation.queues"), css_class: "mb-4 border-b") do
            ::Community::Reporting::BrowseReports::STATES.each_key do |state|
              queue_tab(state, t("community.reports.queues.#{state}"))
            end
            queue_tab("active", t("community.suspensions.active"))
            queue_tab("lifted", t("community.suspensions.lifted_tab"))
          end
          if %w[active lifted].include?(@state)
            render ::Community::SuspensionQueue.new(suspensions: @queue_page.entries, state: @state)
          elsif @queue_page.entries.empty?
            p(class: "ui-empty") { t("community.reports.empty.#{@state}") }
          else
            render ::Community::ReportTable.new(reports: @queue_page.entries, resolved: @state == "resolved")
          end
          pagination
        end
      end

      private

      def queue_tab(state, label)
        a(href: queue_path(state), aria: { current: ("page" if @state == state) }) do
          plain label
        end
      end

      def pagination
        number = @queue_page.number
        total = @queue_page.total_pages
        return if total == 1

        nav(class: "community-board-pagination", aria: { label: t("community.moderation.pagination") }) do
          if number > 1
            text_link(t("community.pagination.previous"), queue_path(@state, page: number - 1), rel: "prev")
          end
          span { t("ui.search.pagination.page", number:, total:) }
          if number < total
            text_link(t("community.pagination.next"), queue_path(@state, page: number + 1), rel: "next")
          end
        end
      end

      def queue_path(state, **params)
        case state
        when "active" then community_suspensions_path(**params)
        when "lifted" then community_suspensions_path(state:, **params)
        else community_moderation_reports_path(state: (state unless state == "open"), **params)
        end
      end
    end
  end
end
