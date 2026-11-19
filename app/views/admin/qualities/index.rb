module Views
  module Admin
    module Qualities
      class Index < ::Views::Admin::Base
        def initialize(page:, query:)
          @page, @query = page, query
        end

        def view_template
          dashboard(title: t("registry.qualities"), resource: :qualities, heading: false) do
            render ::Admin::Collection.new(page: @page, path: admin_qualities_path, label: t("admin.search.qualities"), query: @query) do
              render ::Admin::Qualities::Collection.new(page: @page)
            end
          end
        end
      end
    end
  end
end
