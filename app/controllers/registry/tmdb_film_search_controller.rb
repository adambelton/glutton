module Registry
  class TmdbFilmSearchController < BaseController
    def index
      collection_search = catalogue_search_parameters
      tmdb_search = tmdb_search_parameters
      return render_invalid_parameters unless collection_search.present? && tmdb_search.present?

      tmdb_query = tmdb_search.query.strip
      tmdb_result = CatalogueQueries::SearchTmdbFilmsForImport.call(query: tmdb_query, page: tmdb_search.page, batch: tmdb_search.batch) if tmdb_query.present?
      render_tmdb_search(collection_search:, tmdb_query:, tmdb_result:)
    rescue Errors::TmdbUnavailable, Errors::InvalidTmdbResponse, Errors::TmdbConfigurationError
      render_tmdb_search(collection_search:, tmdb_query:, error: t("admin.tmdb.unavailable"), status: :service_unavailable)
    end

    def create
      collection_search = catalogue_search_parameters
      tmdb_search = tmdb_search_parameters
      tmdb_id = params[:tmdb_id]
      unless collection_search.present? && tmdb_search.present? && tmdb_id.is_a?(String) && tmdb_id.match?(/\A[1-9]\d{0,17}\z/)
        return render_invalid_parameters
      end

      destination = import_results_path(collection_search, tmdb_search)
      film = CatalogueMaintenance::ImportDiscoveredFilm.call(tmdb_id: tmdb_id.to_i)
      redirect_to destination, notice: t("admin.tmdb.imported", title: film.title), status: :see_other
    rescue Errors::ImportIncomplete => error
      message = error.existing_film? ? t("admin.tmdb.already_present") : t("admin.tmdb.import_failed", reason: error.message)
      redirect_to destination, alert: message, status: :see_other
    end

    private

    def tmdb_search_parameters
      TmdbFilmSearchParameters.parse(query: params.fetch(:tmdb_query, ""), page: params.fetch(:tmdb_page, "1"),
        batch: params.fetch(:tmdb_batch, "1"), allow_blank_query: true)
    end

    def import_results_path(collection_search, tmdb_search)
      context = catalogue_context(collection_search)
      tmdb_query = tmdb_search.query.strip
      return admin_films_path(**context) if tmdb_query.blank?

      tmdb_search_admin_films_path(**context, tmdb_query:, tmdb_page: tmdb_search.page,
        tmdb_batch: (tmdb_search.batch unless tmdb_search.batch == "1"))
    end

    def render_tmdb_search(collection_search:, tmdb_query:, tmdb_result: nil, error: nil, status: :ok)
      context = catalogue_context(collection_search)
      if turbo_frame_request_id == ::Admin::Films::TmdbSearchResultsFrame::FRAME_ID
        render ::Admin::Films::TmdbSearchResultsFrame.new(query: tmdb_query, result: tmdb_result, error:, catalogue_context: context), status:
      else
        page = CatalogueQueries::InspectCatalogue.films(page: collection_search.page, title_query: collection_search.query)
        render ::Views::Admin::Films::Index.new(page:, query: collection_search.query, tmdb_query:,
          tmdb_result:, tmdb_error: error, catalogue_context: context), status:
      end
    end
  end
end
