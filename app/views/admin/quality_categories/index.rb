module Views
  module Admin
    module QualityCategories
      class Index < ::Views::Admin::Base
        def initialize(page:, query:)
          @page, @query = page, query
        end

        def view_template
          dashboard(title: t("registry.categories"), resource: :categories, heading: false) do
            search = collection_search(path: admin_quality_categories_path, label: t("admin.search.quality_categories"), query: @query)
            pagination = collection_pagination(page: @page, path: admin_quality_categories_path, query: @query)
            render ::Admin::Collection.new(page: @page, query: @query, search:, pagination:) do
              render ::Admin::QualityCategories::Collection.new(page: @page)
            end
          end
        end
      end
    end
  end
end
