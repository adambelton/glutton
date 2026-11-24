module Views
  module Community
    class Board < ::Views::Base
      def initialize(curations_page:, can_post:)
        @curations_page = curations_page
        @can_post = can_post
      end

      def view_template
        page(title: t("community.title")) do
          if @can_post
            text_link(t("community.curations.create"), new_community_curation_path)
          end
          if @curations_page.entries.any?
            ul(class: "community-curation-list") do
              @curations_page.entries.each do |entry|
                li { render ::Community::CurationCard.new(entry:) }
              end
            end
            pagination if @curations_page.total_pages > 1
          else
            p(class: "ui-empty") { t("community.curations.board_empty") }
          end

          text_link(t("community.curations.complete_setup"), account_community_path) unless @can_post
        end
      end

      private

      def pagination
        number = @curations_page.number
        total = @curations_page.total_pages
        nav(class: "community-board-pagination", aria: { label: t("community.pagination.label") }) do
          if number > 1
            text_link(t("community.pagination.previous"), community_path(page: (number - 1 if number > 2)), rel: "prev")
          end
          span { t("community.pagination.page", number:, total:) }
          if number < total
            text_link(t("community.pagination.next"), community_path(page: number + 1), rel: "next")
          end
        end
      end
    end
  end
end
