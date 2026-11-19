module Registry
  class QualitiesController < BaseController
    def index
      render ::Views::Admin::Qualities::Index.new(page: CatalogueQueries::InspectCatalogue.qualities(page: @page_number, query: @query), query: @query)
    end

    def show
      render ::Views::Admin::Qualities::Show.new(detail: CatalogueQueries::InspectCatalogue.quality(id: params[:id], page: @page_number))
    end
  end
end
