module Library
  class FilmSearchController < ApplicationController
    RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
    rate_limit to: 30, within: 1.minute, store: RATE_LIMIT_STORE, name: :search, only: :index, with: :limited
    rate_limit to: 10, within: 1.hour, store: RATE_LIMIT_STORE, name: :selection,
      only: [ :add_to_watchlist, :add_to_watched, :move_watchlist_to_watched ], with: :limited

    rescue_from Registry::Errors::InvalidTmdbSearch, with: :invalid_search
    rescue_from Registry::Errors::TmdbUnavailable, Registry::Errors::InvalidTmdbResponse,
      Registry::Errors::TmdbConfigurationError, with: :search_unavailable
    rescue_from Registry::Errors::ImportIncomplete, with: :import_failed
    rescue_from Library::Errors::AddToWatchlistUnavailable, Library::Errors::AddToWatchedUnavailable, Library::Errors::AlreadyWatched,
      Library::Errors::FilmUnavailable, with: :action_unavailable
    rescue_from Identity::Errors::Unavailable do
      render ::Views::Library::SignedOut.new, status: :unauthorized
    end

    def index
      raise Registry::Errors::InvalidTmdbSearch unless valid_search?

      result = FilmSearch::Results.call(user_id: current_user.id, query: params[:query], page: page_number, batch:)
      render ::Views::Library::FilmSearch.new(query: params[:query], page_number:, result:)
    end

    def add_to_watchlist
      FilmSearch::AddToLibraryFromSearch.call(user_id: current_user.id, tmdb_id: tmdb_id_param,
        library_action: CollectionManagement::AddToWatchlist)
      redirect_to results_path, notice: t("library.detail.watchlisted"), status: :see_other
    end

    def add_to_watched
      FilmSearch::AddToLibraryFromSearch.call(user_id: current_user.id, tmdb_id: tmdb_id_param,
        library_action: CollectionManagement::AddToWatched)
      redirect_to results_path, notice: t("library.detail.watched"), status: :see_other
    end

    def move_watchlist_to_watched
      id = params[:library_film_id]
      raise Registry::Errors::InvalidTmdbSearch unless valid_search? && valid_id?(id)

      CollectionManagement::MoveWatchlistToWatched.call(user_id: current_user.id, library_film_id: id.to_i)
      redirect_to results_path, notice: t("library.detail.watched"), status: :see_other
    end

    private

    def tmdb_id_param
      id = params[:tmdb_id]
      unless valid_search? && valid_id?(id)
        raise Registry::Errors::InvalidTmdbSearch
      end

      id.to_i
    end

    def valid_id?(id)
      id.is_a?(String) && id.match?(/\A[1-9]\d{0,17}\z/)
    end

    def valid_search?
      query = params[:query]
      page = params.fetch(:page, "1")
      query.is_a?(String) && query.valid_encoding? && (1..200).cover?(query.strip.length) &&
        page.is_a?(String) && page.match?(/\A[1-9]\d{0,2}\z/) && page.to_i <= 500 &&
        batch.is_a?(String) && batch.match?(/\A(?:[1-9]\d{0,2}|last)\z/)
    end

    def batch
      params.fetch(:batch, "1")
    end

    def page_number
      params.fetch(:page, "1").to_i
    end

    def results_path
      library_film_search_path(query: params[:query], page: page_number, batch: (batch unless batch == "1"))
    end

    def invalid_search
      render_search_error(:invalid, :bad_request)
    end

    def search_unavailable
      render_search_error(:unavailable, :service_unavailable)
    end

    def import_failed(error)
      redirect_to results_path, alert: t("library.search.import_failed", reason: error.message), status: :see_other
    end

    def action_unavailable
      redirect_to results_path, alert: t("library.search.action_unavailable"), status: :see_other
    end

    def limited
      render_search_error(:limited, :too_many_requests)
    end

    def render_search_error(key, status)
      query = params[:query] if valid_search?
      render ::Views::Library::FilmSearch.new(query:, error: t("library.search.#{key}")), status:
    end
  end
end
