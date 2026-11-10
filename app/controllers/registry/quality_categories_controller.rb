module Registry
  class QualityCategoriesController < BaseController
    def index
      render ::Views::Registry::CategoriesIndex.new(page: CatalogueQueries::InspectCatalogue.categories(page: @page_number))
    end

    def show
      render ::Views::Registry::CategoryDetail.new(detail: CatalogueQueries::InspectCatalogue.category(id: params[:id], page: @page_number))
    end
  end
end
