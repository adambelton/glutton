module Library
  class FilmSearchForm < Shared::Base
    def initialize(query: nil, dropdown: false)
      @query, @dropdown = query, dropdown
    end

    def view_template
      div(class: "library-film-search-field", data: { controller: "library-film-search",
        action: "click@document->library-film-search#dismissOutside keydown.esc->library-film-search#dismiss resize@window->library-film-search#fitDropdown scroll@window->library-film-search#fitDropdown",
        library_film_search_error_value: t("library.search.unavailable") }) do
        form_with(url: library_film_search_path, method: :get, class: "library-film-search-form", role: "search",
          data: { action: "submit->library-film-search#submit" }) do
          span(class: "library-film-search-spinner", role: "status", hidden: true,
            data: { library_film_search_target: "spinner" }) do
            span(class: "sr-only") { t("library.search.loading") }
          end
          label(for: "library-film-query", class: "sr-only") { t("library.search.label") }
          input(id: "library-film-query", type: "search", name: "query", value: @query,
            class: "ui-input", placeholder: t("library.search.placeholder"), required: true, maxlength: 200,
            aria: { controls: "library-film-search-results" },
            data: { action: "input->library-film-search#schedule compositionend->library-film-search#schedule focus->library-film-search#reopen" })
        end
        if @dropdown
          section(id: "library-film-search-results", class: "library-film-search-dropdown", aria: { live: "polite" },
            data: { action: "click->library-film-search#paginate" }, hidden: true)
        end
      end
    end
  end
end
