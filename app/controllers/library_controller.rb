class LibraryController < ApplicationController
  rescue_from Identity::Errors::Required, Identity::Errors::Unavailable do
    render ::Views::Library::SignedOut.new, status: :unauthorized
  end

  rescue_from Library::Errors::FilmUnavailable do
    @error = I18n.t("library.detail.unavailable")
    render ::Views::Library::Unavailable.new(error: @error), status: :not_found
  end
  rescue_from Library::Errors::AlreadyWatched do
    @error = I18n.t("library.detail.watch_unavailable")
    render ::Views::Library::Unavailable.new(error: @error), status: :conflict
  end
  rescue_from Library::Errors::NotOnWatchlist do
    @error = I18n.t("library.detail.not_on_watchlist")
    render ::Views::Library::Unavailable.new(error: @error), status: :conflict
  end

  def film
    @library_film = Library::CollectionManagement::FindFilm.call(user_id: current_user.id, library_film_id: library_film_id_param)
    render ::Views::Library::FilmDetail.new(library_film: @library_film)
  end

  def mark_watched
    library_film = Library::CollectionManagement::RecordWatched.call(user_id: current_user.id, library_film_id: library_film_id_param)
    redirect_to library_film_path(library_film), notice: I18n.t("library.detail.watched"), status: :see_other
  end

  def add_to_watchlist_from_ratings
    library_film = Library::CollectionManagement::AddToWatchlist.call(user_id: current_user.id, film_id: shortcut_film_id)
    flash[:ratings_excluded_film_id] = library_film.film_id
    redirect_to new_rating_path, notice: I18n.t("library.detail.watchlisted"), status: :see_other
  rescue Library::Errors::AddToWatchlistUnavailable, Library::Errors::FilmUnavailable
    redirect_to new_rating_path, alert: I18n.t("library.detail.watchlist_unavailable"), status: :see_other
  end

  def mark_watched_from_recommendations
    library_film = Library::CollectionManagement::MarkFilmWatched.call(user_id: current_user.id, film_id: shortcut_film_id)
    flash[:recommendations_excluded_film_id] = library_film.film_id
    redirect_to recommendation_path, notice: I18n.t("library.detail.watched"), status: :see_other
  rescue Library::Errors::AlreadyWatched, Library::Errors::FilmUnavailable
    redirect_to recommendation_path, alert: I18n.t("library.detail.watch_unavailable"), status: :see_other
  end

  def remove_from_watchlist
    Library::CollectionManagement::RemoveFromWatchlist.call(user_id: current_user.id, library_film_id: library_film_id_param)
    redirect_to library_path, notice: I18n.t("library.detail.removed"), status: :see_other
  end

  def show
    @view = params.fetch(:view, Library::CollectionManagement::Browse::Views::WATCHLIST)
    page = params.fetch(:page, "1")
    unless Library::CollectionManagement::Browse::Views::ALL.include?(@view) && page.is_a?(String) && page.match?(/\A[1-9]\d{0,8}\z/)
      render ::Views::Library::Invalid.new, status: :bad_request
      return
    end
    @page_number = page.to_i
    @page = Library::CollectionManagement::Browse.call(user_id: current_user.id, view: @view, page: @page_number)
    render ::Views::Library::Browse.new(view: @view, page: @page, page_number: @page_number)
  end

  private

  def shortcut_film_id
    id = params[:film_id]
    raise Library::Errors::FilmUnavailable unless id.is_a?(String) && id.match?(/\A[1-9]\d{0,18}\z/)

    id.to_i
  end

  def library_film_id_param
    id = params[:id]
    raise Library::Errors::FilmUnavailable unless id.is_a?(String) && id.match?(/\A[1-9]\d*\z/)

    id
  end
end
