module Library
  class FilmSearchController < ApplicationController
    include FilmSearchContext

    RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
    rate_limit to: 30, within: 1.minute, store: RATE_LIMIT_STORE, name: :search, only: :index, with: :limited

    rescue_from Registry::Errors::InvalidTmdbSearch, with: :invalid_search
    rescue_from Registry::Errors::TmdbUnavailable, Registry::Errors::InvalidTmdbResponse,
      Registry::Errors::TmdbConfigurationError, with: :search_unavailable
    rescue_from Identity::Errors::Unavailable do
      render ::Views::Library::SignedOut.new, status: :unauthorized
    end

    def index
      raise Registry::Errors::InvalidTmdbSearch unless valid_film_search?

      result = FilmSearch::SearchFilmsForLibrary.call(user_id: current_user.id, query: params[:query],
        page: film_search_page_number, batch: film_search_batch)
      render ::Views::Library::FilmSearch.new(query: params[:query], page_number: film_search_page_number, result:)
    end

    private

    def invalid_search
      render_film_search_error(:invalid, :bad_request)
    end

    def search_unavailable
      render_film_search_error(:unavailable, :service_unavailable)
    end

    def limited
      render_film_search_error(:limited, :too_many_requests)
    end
  end
end
