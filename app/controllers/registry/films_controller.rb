module Registry
  class FilmsController < BaseController
    def index
      collection_search = catalogue_search_parameters
      return render_invalid_parameters unless collection_search.present?

      page = CatalogueQueries::BrowseCatalogue.films(page: collection_search.page, title_query: collection_search.query)
      render ::Views::Admin::Films::Index.new(page:, query: collection_search.query, catalogue_context: catalogue_context(collection_search))
    end

    def show
      page = catalogue_page_number
      return render_invalid_parameters unless page.present?

      render ::Views::Admin::Films::Show.new(detail: CatalogueQueries::BrowseCatalogue.film(id: catalogue_record_id, page:))
    end
  end
end
