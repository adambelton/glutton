module Library
  class TmdbFilmSearchController < ApplicationController
    SELECTION_ACTIONS = %i[add_to_watchlist add_to_watched].freeze
    RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
    SELECTION_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

    rate_limit to: 30, within: 1.minute, store: RATE_LIMIT_STORE, name: :search, only: :index, with: :limited
    rate_limit to: 10, within: 1.hour, store: SELECTION_LIMIT_STORE, name: :selection, only: SELECTION_ACTIONS, with: :limited

    rescue_from Registry::Errors::InvalidTmdbSearch, with: :invalid_search
    rescue_from Registry::Errors::TmdbUnavailable, Registry::Errors::InvalidTmdbResponse,
      Registry::Errors::TmdbConfigurationError, with: :search_unavailable
    rescue_from Identity::Errors::Unavailable do
      render ::Views::Library::SignedOut.new, status: :unauthorized
    end

    def index
      tmdb_search = TmdbFilmSearchRequest.parse(params)
      return invalid_search unless tmdb_search.present?

      provider_parameters = tmdb_search.provider_parameters
      result = TmdbFilmSearch::SearchTmdbFilmsForLibrary.call(user_id: current_user.id, query: provider_parameters.query,
        page: provider_parameters.page, offset: tmdb_search.offset, backwards: tmdb_search.backwards, legacy_batch: tmdb_search.legacy_batch)
      render ::Views::Library::TmdbFilmSearch.new(query: provider_parameters.query, number: tmdb_search.number, result:)
    end

    def add_to_watchlist
      add_selected_film(library_action: CollectionManagement::AddToWatchlist, notice: "library.detail.watchlisted")
    end

    def add_to_watched
      add_selected_film(library_action: CollectionManagement::AddToWatched, notice: "library.detail.watched")
    end

    private

    def add_selected_film(library_action:, notice:)
      tmdb_search = TmdbFilmSearchRequest.parse(params)
      tmdb_id = params[:tmdb_id]
      return invalid_search unless tmdb_search.present? && tmdb_id.is_a?(String) && tmdb_id.match?(/\A[1-9]\d{0,17}\z/)

      destination = tmdb_results_path(tmdb_search)
      TmdbFilmSearch::AddTmdbFilmToLibrary.call(user_id: current_user.id, tmdb_id: tmdb_id.to_i, library_action:)
      redirect_to destination, notice: t(notice), status: :see_other
    rescue Registry::Errors::ImportIncomplete => error
      redirect_to destination, alert: t("library.search.import_failed", reason: error.message), status: :see_other
    rescue Errors::AddToWatchlistUnavailable, Errors::AddToWatchedUnavailable, Errors::FilmUnavailable
      redirect_to destination, alert: t("library.search.action_unavailable"), status: :see_other
    end

    def tmdb_results_path(tmdb_search)
      provider_parameters = tmdb_search.provider_parameters
      library_tmdb_film_search_path(query: provider_parameters.query, page: provider_parameters.page,
        offset: (tmdb_search.offset if params.key?(:offset)), number: (tmdb_search.number if params.key?(:number)),
        batch: (provider_parameters.batch unless provider_parameters.batch == "1"))
    end

    def invalid_search
      render_search_error(:invalid, :bad_request)
    end

    def search_unavailable
      render_search_error(:unavailable, :service_unavailable)
    end

    def limited
      render_search_error(:limited, :too_many_requests)
    end

    def render_search_error(key, status)
      query = TmdbFilmSearchRequest.parse(params)&.provider_parameters&.query
      render ::Views::Library::TmdbFilmSearch.new(query:, error: t("library.search.#{key}")), status:
    end
  end
end
