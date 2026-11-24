class LibraryController < ApplicationController
  rescue_from Identity::Errors::Unavailable, Identity::Errors::Required, with: :render_signed_out

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

  rescue_from Library::Errors::NotWatched do
    @error = I18n.t("library.detail.not_watched")
    render ::Views::Library::Unavailable.new(error: @error), status: :conflict
  end

  def move_to_watchlist
    Library::CollectionManagement::MoveWatchedToWatchlist.call(user_id: current_user.id, library_film_id: library_film_id_param)
    redirect_to library_path, status: :see_other
  end

  def remove_from_watched
    Library::CollectionManagement::RemoveFromWatched.call(user_id: current_user.id, library_film_id: library_film_id_param)
    redirect_to library_path(view: Library::CollectionManagement::BrowseFilmCollection::Views::WATCHED),
      notice: I18n.t("library.detail.removed_from_library"), status: :see_other
  end

  def move_to_watched
    library_film = Library::CollectionManagement::MoveWatchlistToWatched.call(user_id: current_user.id, library_film_id: library_film_id_param)
    redirect_to(library_film.can_rate? ? new_rating_path(film_id: library_film.film_id) :
      library_path(view: Library::CollectionManagement::BrowseFilmCollection::Views::WATCHED), status: :see_other)
  end

  def add_to_watchlist_from_ratings
    library_film = Library::CollectionManagement::AddToWatchlist.call(user_id: current_user.id, film_id: shortcut_film_id)
    flash[:ratings_excluded_film_id] = library_film.film_id
    redirect_to new_rating_path, notice: I18n.t("library.detail.watchlisted"), status: :see_other
  rescue Library::Errors::AddToWatchlistUnavailable, Library::Errors::FilmUnavailable
    redirect_to new_rating_path, alert: I18n.t("library.detail.watchlist_unavailable"), status: :see_other
  end

  def add_to_watched_from_recommendations
    library_film = Library::CollectionManagement::AddToWatched.call(user_id: current_user.id, film_id: shortcut_film_id)
    flash[:recommendations_excluded_film_id] = library_film.film_id
    redirect_to recommendation_path, notice: I18n.t("library.detail.watched"), status: :see_other
  rescue Library::Errors::AddToWatchedUnavailable, Library::Errors::FilmUnavailable
    redirect_to recommendation_path, alert: I18n.t("library.detail.watch_unavailable"), status: :see_other
  end

  def remove_from_watchlist
    Library::CollectionManagement::RemoveFromWatchlist.call(user_id: current_user.id, library_film_id: library_film_id_param)
    redirect_to library_path, notice: I18n.t("library.detail.removed"), status: :see_other
  end

  def show
    view = params.fetch(:view, Library::CollectionManagement::BrowseFilmCollection::Views::WATCHLIST)
    collection_search = CollectionSearchParameters.parse(query: params.fetch(:q, ""), page: params.fetch(:page, "1"), max_digits: 9)
    ratings = params.fetch(:ratings, [])
    unless Library::CollectionManagement::BrowseFilmCollection::Views::ALL.include?(view) &&
        collection_search.present? && valid_rating_filters?(ratings, view:)
      return render ::Views::Library::Invalid.new, status: :bad_request
    end

    ratings = ratings.uniq
    page = Library::CollectionManagement::BrowseFilmCollection.call(user_id: current_user.id, view:, page: collection_search.page, ratings:, title_query: collection_search.query)
    render ::Views::Library::FilmCollection.new(view:, page:, page_number: collection_search.page, ratings:, query: collection_search.query)
  end

  private

  def render_signed_out
    render ::Views::Library::SignedOut.new, status: :unauthorized
  end

  def valid_rating_filters?(ratings, view:)
    ratings.is_a?(Array) && (ratings.empty? || (view == Library::CollectionManagement::BrowseFilmCollection::Views::WATCHED &&
      (ratings - Library::CollectionManagement::BrowseFilmCollection::RATING_FILTERS).empty?))
  end

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
