module Views
  module Community
    class Board < ::Views::Base
      RESULTS_FRAME = "community-board-results"

      def initialize(posts_page:, can_post:, query:)
        @posts_page = posts_page
        @can_post = can_post
        @query = query
      end

      def view_template
        page(title: t("community.title"), class: "community-board-page", heading_outside_card: true, heading_action: search_form) do
          div(class: "community-board-actions flex justify-end pb-2") { create_curation_action } if @can_post
          tag(:turbo_frame, id: RESULTS_FRAME, target: "_top", aria: { live: "polite" }) do
            post_list
            text_link(t("community.curations.complete_setup"), account_community_path) unless @can_post
            pagination
          end
        end
      end

      private

      def search_form
        Shared::CollectionSearchForm.new(path: community_path, clear_path: community_path, label: t("community.search.label"),
          query: @query, input_id: "community-board-query", frame: RESULTS_FRAME, css_class: "community-board-search")
      end

      def post_list
        if @posts_page.entries.any?
          ul(class: "community-post-grid") do
            @posts_page.entries.each do |entry|
              li { render card_for(entry) }
            end
          end
        else
          p(class: "ui-empty") { t(@query.present? ? "community.search.no_matches" : "community.board_empty") }
        end
      end

      def card_for(entry)
        case entry
        when ::Community::Board::BrowseCurations::BoardEntry
          ::Community::CurationCard.new(entry:)
        when ::Community::Board::BrowseCommunityBoard::DebriefEntry
          ::Community::FilmDebriefCard.new(entry:, can_post: @can_post)
        end
      end

      def create_curation_action
        render RubyUI::Link.new(href: new_community_curation_path, variant: :primary, size: :xl, class: "ui-action-button h-auto max-w-full") do
          t("community.curations.create")
        end
      end

      def pagination
        number = @posts_page.number
        total = @posts_page.total_pages
        nav(class: "community-board-pagination", aria: { label: t("community.pagination.label") }) do
          if number > 1
            text_link(t("community.pagination.previous"), community_path(q: @query.presence, page: (number - 1 if number > 2)),
              rel: "prev", data: { turbo_frame: RESULTS_FRAME })
          end
          span { t("community.pagination.page", number:) }
          if number < total
            text_link(t("community.pagination.next"), community_path(q: @query.presence, page: number + 1),
              rel: "next", data: { turbo_frame: RESULTS_FRAME })
          end
        end
      end
    end
  end
end
