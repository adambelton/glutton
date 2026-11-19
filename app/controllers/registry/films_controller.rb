module Registry
  class FilmsController < BaseController
    def index
      render ::Views::Admin::Films::Index.new(page: CatalogueQueries::InspectCatalogue.films(page: @page_number, query: @query), query: @query)
    end

    def show
      render ::Views::Admin::Films::Show.new(detail: CatalogueQueries::InspectCatalogue.film(id: params[:id], page: @page_number))
    end
  end
end
