module Library
  class TmdbFilmSearchForm < Shared::Base
    def initialize(query: nil, dropdown: false)
      @query, @dropdown = query, dropdown
    end

    def view_template
      div(class: "library-film-search-field", data: { controller: "library-tmdb-film-search",
        action: "click@document->library-tmdb-film-search#dismissOutside keydown.esc->library-tmdb-film-search#dismiss resize@window->library-tmdb-film-search#fitDropdown scroll@window->library-tmdb-film-search#fitDropdown",
        library_tmdb_film_search_error_value: t("library.search.unavailable") }) do
        form_with(url: library_tmdb_film_search_path, method: :get, class: "library-film-search-form", role: "search",
          data: { action: "submit->library-tmdb-film-search#submit" }) do
          render Shared::CollectionSearchField.new(input_id: "library-film-query", name: "query", query: @query,
            label: t("library.search.label"), placeholder: t("library.search.placeholder"), required: true, maxlength: 200,
            controls: "library-film-search-results", clear_path: (library_path unless @dropdown),
            loading: { label: t("library.search.loading"), data: { library_tmdb_film_search_target: "spinner" } },
            input_data: { action: "input->library-tmdb-film-search#schedule compositionend->library-tmdb-film-search#schedule focus->library-tmdb-film-search#reopen" },
            clear_data: { library_tmdb_film_search_target: "clearButton", action: ("library-tmdb-film-search#clear" if @dropdown) })
        end
        if @dropdown
          render Shared::FilmSearchDropdown.new(id: "library-film-search-results", css_class: "library-film-search-dropdown",
            aria: { live: "polite" }, data: { action: "click->library-tmdb-film-search#paginate submit->library-tmdb-film-search#selectFilm" }, hidden: true)
        end
      end
    end
  end
end
