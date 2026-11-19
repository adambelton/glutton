module Registry
  class FilmSearchController < BaseController
    include FilmSearchParameters

    before_action :validate_tmdb_parameters

    rescue_from Errors::TmdbUnavailable, Errors::InvalidTmdbResponse, Errors::TmdbConfigurationError, with: :search_unavailable

    def index
      result = CatalogueQueries::SearchFilmsForImport.call(query: @tmdb_query, page: @tmdb_page, batch: @tmdb_batch) if @tmdb_query.present?
      render_collection(result:)
    end

    private

    def render_collection(result: nil, error: nil, status: :ok)
      if turbo_frame_request_id == ::Admin::Films::TmdbResults::FRAME_ID
        render ::Admin::Films::TmdbResults.new(query: @tmdb_query, result:, error:, catalogue_context:), status:
      else
        page = CatalogueQueries::InspectCatalogue.films(page: @page_number, query: @query)
        render ::Views::Admin::Films::Index.new(page:, query: @query, tmdb_query: @tmdb_query,
          tmdb_result: result, tmdb_error: error, catalogue_context:), status:
      end
    end

    def search_unavailable
      render_collection(error: t("admin.tmdb.unavailable"), status: :service_unavailable)
    end
  end
end
