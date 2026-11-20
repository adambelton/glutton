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
            pagination = collection_pagination(page: @page, path: admin_films_path, query: @query)
            render ::Admin::Collection.new(page: @page, query: @query, search: search_bar, pagination:) do
              render ::Admin::Films::Collection.new(page: @page)
            end
          end
        end

        private

        def search_bar
          modes = [
            Shared::SearchBar::Mode.new(key: "local", label: t("registry.films"), form: film_collection_search),
            Shared::SearchBar::Mode.new(key: "tmdb", label: t("ui.search.tmdb"), form: tmdb_search)
          ]
          Shared::SearchBar.new(label: t("ui.search.mode"), modes:, selected: (@tmdb_query.present? ? "tmdb" : "local"), toggle_position: :end)
        end

        def film_collection_search
          collection_search(path: admin_films_path, label: t("admin.search.films"), query: @query)
        end

        def tmdb_search
          results = ::Admin::Films::TmdbSearchResultsFrame.new(query: @tmdb_query, result: @tmdb_result, error: @tmdb_error,
            catalogue_context: @catalogue_context)
          ::Admin::Films::TmdbSearchForm.new(query: @tmdb_query, results:, catalogue_context: @catalogue_context)
        end
      end
    end
  end
end
