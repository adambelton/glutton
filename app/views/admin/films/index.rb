module Views
  module Admin
    module Films
      class Index < ::Views::Admin::Base
        def initialize(page:, query:)
          @page, @query = page, query
        end

        def view_template
          dashboard(title: t("registry.films"), resource: :films, heading: false) do
            render ::Admin::Collection.new(page: @page, path: admin_films_path, label: t("admin.search.films"), query: @query) do
              render ::Admin::Films::Collection.new(page: @page)
            end
          end
        end
      end
    end
  end
end
