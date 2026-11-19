module Views
  module Admin
    module Films
      class Index < ::Views::Admin::Base
        def initialize(page:, query:, catalogue_context:, tmdb_query: "", tmdb_result: nil, tmdb_error: nil)
          @page, @query = page, query
          @tmdb_query, @tmdb_result, @tmdb_error = tmdb_query, tmdb_result, tmdb_error
          @catalogue_context = catalogue_context
        end

        def view_template
          dashboard(title: t("registry.films"), resource: :films, heading: false) do
            render ::Admin::Collection.new(page: @page, path: admin_films_path, label: t("admin.search.films"),
              query: @query, companion: tmdb_search) do
              render ::Admin::Films::Collection.new(page: @page)
            end
          end
        end

        private

        def tmdb_search
          results = ::Admin::Films::TmdbResults.new(query: @tmdb_query, result: @tmdb_result, error: @tmdb_error,
            catalogue_context: @catalogue_context)
          ::Admin::Films::TmdbSearch.new(query: @tmdb_query, results:, catalogue_context: @catalogue_context)
        end
      end
    end
  end
end
