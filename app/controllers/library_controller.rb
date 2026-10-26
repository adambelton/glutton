class LibraryController < ApplicationController
  before_action :require_identity

  rescue_from Identity::Required, Library::IdentityUnavailable do
    render :signed_out, status: :unauthorized
  end

  rescue_from Library::FilmUnavailable do
    @error = I18n.t("library.detail.unavailable")
    render :unavailable, status: :not_found
  end
  rescue_from Library::AlreadyWatched do
    @error = I18n.t("library.detail.watch_unavailable")
    render :unavailable, status: :conflict
  end
  rescue_from Library::NotOnWatchlist do
    @error = I18n.t("library.detail.not_on_watchlist")
    render :unavailable, status: :conflict
  end

  def film
    @library_film = Library::FindFilm.call(user_id: current_user.id, library_film_id: library_film_id_param)
  end

  def mark_watched
    library_film = Library::WatchFilm.call(user_id: current_user.id, library_film_id: library_film_id_param)
    redirect_to library_film_path(library_film), notice: I18n.t("library.detail.watched"), status: :see_other
  end

  def remove_from_watchlist
    Library::RemoveWatchlistFilm.call(user_id: current_user.id, library_film_id: library_film_id_param)
    redirect_to library_path, notice: I18n.t("library.detail.removed"), status: :see_other
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

  private

  def library_film_id_param
    id = params[:id]
    raise Library::FilmUnavailable unless id.is_a?(String) && id.match?(/\A[1-9]\d*\z/)

    id
  end
end
