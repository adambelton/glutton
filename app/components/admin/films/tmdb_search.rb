module Admin
  module Films
    class TmdbSearch < Shared::Base
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
        form_with(url: search_admin_films_path, method: :get, class: "admin-search", role: "search",
          data: { turbo_frame: TmdbResults::FRAME_ID, admin_tmdb_search_target: "form", action: "submit->admin-tmdb-search#submit" }) do
          input(type: "hidden", name: "q", value: @catalogue_context[:q].to_s)
          input(type: "hidden", name: "page", value: @catalogue_context.fetch(:page, 1))
          div(class: "admin-search-field") do
            label = t("admin.tmdb.search")
            input(type: "search", name: "tmdb_query", value: @query, placeholder: label,
              aria: { label:, controls: TmdbResults::FRAME_ID }, maxlength: 200, autocomplete: "off", class: "ui-input",
              data: { admin_tmdb_search_target: "input",
                action: "input->admin-tmdb-search#schedule compositionend->admin-tmdb-search#schedule keydown.esc->admin-tmdb-search#clear" })
            a(href: admin_films_path(**@catalogue_context), class: "admin-clear-search", hidden: @query.blank?,
              title: t("admin.tmdb.clear"), aria: { label: t("admin.tmdb.clear") },
              data: { admin_tmdb_search_target: "clearButton", action: "click->admin-tmdb-search#clear" }) do
              span(aria: { hidden: "true" }) { "×" }
            end
          end
        end
      end
    end
  end
end
