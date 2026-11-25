module Community
  class BoardController < ApplicationController
    before_action :require_preview_access

    def show
      search = CollectionSearchParameters.parse(query: params.fetch(:q, ""), page: params.fetch(:page, "1"), max_digits: 6)
      return redirect_to community_path unless search.present?

      posts_page = BrowseCommunityBoard.page(viewer: current_user, number: search.page, query: search.query)
      if search.page > posts_page.total_pages
        return redirect_to community_path(q: search.query.presence, page: (posts_page.total_pages if posts_page.total_pages > 1))
      end

      render Views::Community::Board.new(posts_page:, query: search.query,
        can_post: PostingAccess.allowed?(user: current_user))
    end

    private

    def require_preview_access
      head :forbidden unless PreviewAccess.allowed?(user: current_user)
    end
  end
end
