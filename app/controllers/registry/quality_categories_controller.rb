module Registry
  class QualityCategoriesController < BaseController
    def index
      render ::Views::Admin::QualityCategories::Index.new(page: CatalogueQueries::InspectCatalogue.categories(page: @page_number, query: @query), query: @query)
    end

    def show
      render ::Views::Admin::QualityCategories::Show.new(detail: CatalogueQueries::InspectCatalogue.category(id: params[:id], page: @page_number))
    end
  end
end
