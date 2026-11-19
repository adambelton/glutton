module Registry
  class FilmsController < BaseController
    include FilmSearchParameters

    before_action :validate_tmdb_parameters, only: :create

    rescue_from Errors::ImportIncomplete, with: :import_failed

    def index
      page = CatalogueQueries::InspectCatalogue.films(page: @page_number, query: @query)
      render ::Views::Admin::Films::Index.new(page:, query: @query, catalogue_context:)
    end

    def show
      render ::Views::Admin::Films::Show.new(detail: CatalogueQueries::InspectCatalogue.film(id: params[:id], page: @page_number))
    end

    def create
      id = params[:tmdb_id]
      unless id.is_a?(String) && id.match?(/\A[1-9]\d{0,17}\z/)
        render ::Views::Admin::Message.new(key: :invalid), status: :bad_request
        return
      end

      film = CatalogueMaintenance::ImportDiscoveredFilm.call(tmdb_id: id.to_i)
      redirect_to import_results_path, notice: t("admin.tmdb.imported", title: film.title), status: :see_other
    end

    private

    def import_results_path
      return admin_films_path(**catalogue_context) if @tmdb_query.blank?

      search_admin_films_path(**catalogue_context, tmdb_query: @tmdb_query, tmdb_page: @tmdb_page,
        tmdb_batch: (@tmdb_batch unless @tmdb_batch == "1"))
    end

    def import_failed(error)
      message = error.existing_film? ? t("admin.tmdb.already_present") : t("admin.tmdb.import_failed", reason: error.message)
      redirect_to import_results_path, alert: message, status: :see_other
    end
  end
end
