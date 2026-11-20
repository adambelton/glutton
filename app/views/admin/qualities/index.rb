module Views
  module Admin
    module Qualities
      class Index < ::Views::Admin::Base
        def initialize(page:, query:)
          @page, @query = page, query
        end

        def view_template
          dashboard(title: t("registry.qualities"), resource: :qualities, heading: false) do
            search = collection_search(path: admin_qualities_path, label: t("admin.search.qualities"), query: @query)
            pagination = collection_pagination(page: @page, path: admin_qualities_path, query: @query)
            render ::Admin::Collection.new(page: @page, query: @query, search:, pagination:) do
              render ::Admin::Qualities::Collection.new(page: @page)
            end
          end
        end
      end
    end
  end
end
