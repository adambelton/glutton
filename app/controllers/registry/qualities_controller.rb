module Registry
  class QualitiesController < BaseController
    def index
      search = catalogue_search_parameters
      return render_invalid_parameters unless search.present?

      page = CatalogueQueries::BrowseCatalogue.qualities(page: search.page, query: search.query)
      render ::Views::Admin::Qualities::Index.new(page:, query: search.query)
    end

    def show
      page = catalogue_page_number
      return render_invalid_parameters unless page.present?

      render ::Views::Admin::Qualities::Show.new(detail: CatalogueQueries::BrowseCatalogue.quality(id: catalogue_record_id, page:))
    end
  end
end
