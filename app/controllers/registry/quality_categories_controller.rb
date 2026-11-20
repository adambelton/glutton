module Registry
  class QualityCategoriesController < BaseController
    def index
      search = catalogue_search_parameters
      return render_invalid_parameters unless search.present?

      page = CatalogueQueries::InspectCatalogue.categories(page: search.page, query: search.query)
      render ::Views::Admin::QualityCategories::Index.new(page:, query: search.query)
    end

    def show
      page = catalogue_page_number
      return render_invalid_parameters unless page.present?

      render ::Views::Admin::QualityCategories::Show.new(detail: CatalogueQueries::InspectCatalogue.category(id: catalogue_record_id, page:))
    end
  end
end
