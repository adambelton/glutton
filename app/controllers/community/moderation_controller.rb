module Community
  class ModerationController < ApplicationController
    rescue_from Errors::ModerationAccessDenied, with: -> { head :forbidden }

    def show
      search = CollectionSearchParameters.parse(query: "", page: params.fetch(:page, "1"), max_digits: 6)
      state = params.fetch(:state, "open")
      return head :bad_request unless search.present? && Reporting::BrowseReports::STATES.key?(state)

      reports_page = Reporting::BrowseReports.page(viewer: current_user, number: search.page, state:)
      return redirect_to community_moderation_path(state:) unless search.page <= reports_page.total_pages

      render Views::Community::Moderation.new(reports_page:, state:)
    end
  end
end
