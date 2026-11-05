module Registry
  class QualityCategoriesController < BaseController
    def index
      render ::Views::Registry::CategoriesIndex.new(page: InspectCatalogue.categories(page: @page_number))
    end

    def show
      render ::Views::Registry::CategoryDetail.new(detail: InspectCatalogue.category(id: params[:id], page: @page_number))
    end
  end
end
