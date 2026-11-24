module Community
  class BoardController < ApplicationController
    before_action :require_preview_access

    def show
      number = CollectionSearchParameters.page(params.fetch(:page, "1"), max_digits: 6)
      return redirect_to community_path unless number.present?

      curations_page = BrowseCurations.page(number:)
      if number > curations_page.total_pages
        return redirect_to community_path(page: (curations_page.total_pages if curations_page.total_pages > 1))
      end

      render Views::Community::Board.new(curations_page:,
        can_post: PostingAccess.allowed?(user: current_user))
    end

    private

    def require_preview_access
      head :forbidden unless PreviewAccess.allowed?(user: current_user)
    end
  end
end
