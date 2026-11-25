module Views
  module Admin
    class Base < Shared::Base
      private

      def dashboard(title:, resource: nil, heading: true, heading_content: nil, back_to: nil, back_label: nil, &)
        render ::Admin::Dashboard.new(title:, resource:, heading:, heading_content:, back_to:, back_label:), &
      end

      def collection_search(path:, label:, query:, method: :get, parameter: "q")
        Shared::CollectionSearchForm.new(path:, clear_path: path, label:, query:, method:, parameter:,
          input_id: "admin-collection-query", frame: ::Admin::Collection::RESULTS_FRAME, css_class: "admin-search")
      end

      def collection_pagination(page:, path:, query:, method: :get, parameter: "q")
        ::Admin::Pagination.new(page:, path:, query:, method:, parameter:,
          show_count: true, frame: ::Admin::Collection::RESULTS_FRAME)
      end
    end
  end
end
