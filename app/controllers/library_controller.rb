class LibraryController < ApplicationController
  before_action :require_identity

  rescue_from Identity::Required, Library::IdentityUnavailable do
    render :signed_out, status: :unauthorized
  end

  def show
    @view = params.fetch(:view, Library::Browse::Views::WATCHLIST)
    page = params.fetch(:page, "1")
    unless Library::Browse::Views::ALL.include?(@view) && page.is_a?(String) && page.match?(/\A[1-9]\d{0,8}\z/)
      render :invalid, status: :bad_request
      return
    end
    @page_number = page.to_i
    @page = Library::Browse.call(user_id: current_user.id, view: @view, page: @page_number)
  end
end
