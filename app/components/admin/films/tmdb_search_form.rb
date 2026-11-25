module Admin
  module Films
    class TmdbSearchForm < Shared::Base
      def initialize(query:, results:, catalogue_context:)
        @query, @results, @catalogue_context = query, results, catalogue_context
      end

      def view_template
        div(class: "admin-tmdb-search", data: { controller: "admin-tmdb-search",
          action: "turbo:frame-render->admin-tmdb-search#displayResults resize@window->admin-tmdb-search#fitDropdown scroll@window->admin-tmdb-search#fitDropdown" }) do
          search_form
          render @results
        end
      end

      private

      def search_form
        form_with(url: tmdb_search_admin_films_path, method: :get, class: "admin-search", role: "search",
          data: { turbo_frame: TmdbSearchResultsFrame::FRAME_ID, admin_tmdb_search_target: "form", action: "submit->admin-tmdb-search#submit" }) do
          input(type: "hidden", name: "q", value: @catalogue_context[:q].to_s)
          input(type: "hidden", name: "page", value: @catalogue_context.fetch(:page, 1))
          render Shared::CollectionSearchField.new(name: "tmdb_query", query: @query, label: t("admin.tmdb.search"),
            controls: TmdbSearchResultsFrame::FRAME_ID, maxlength: 200, clear_path: admin_films_path(**@catalogue_context),
            clear_label: "admin.tmdb.clear",
            input_data: { admin_tmdb_search_target: "input",
              action: "input->admin-tmdb-search#schedule compositionend->admin-tmdb-search#schedule keydown.esc->admin-tmdb-search#clear focus->admin-tmdb-search#fitDropdown" },
            clear_data: { admin_tmdb_search_target: "clearButton", action: "click->admin-tmdb-search#clear" })
        end
      end
    end
  end
end
