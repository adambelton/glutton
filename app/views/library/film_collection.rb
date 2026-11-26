module Views
  module Library
    class FilmCollection < ::Views::Base
      RESULTS_FRAME = "library-collection-results"

      def initialize(view:, page:, page_number:, ratings:, query:)
        @view, @page, @page_number, @ratings, @query = view, page, page_number, ratings, query
      end

      def view_template
        page(title: t("library.browser.title"), class: "library-page", heading_outside_card: true,
          heading_action: search_bar) do
          tag(:turbo_frame, id: RESULTS_FRAME, target: "_top", aria: { live: "polite" }) do
            render ::Library::FilmCollection.new(view: @view, page: @page, page_number: @page_number, ratings: @ratings, query: @query)
          end
          render ::Library::ActionConfirmationDialog.new
        end
      end

      private

      def search_bar
        modes = [
          Shared::SearchBar::Mode.new(key: "local", label: t("library.browser.title"), form: film_collection_search),
          Shared::SearchBar::Mode.new(key: "tmdb", label: t("ui.search.tmdb"), form: ::Library::TmdbFilmSearchForm.new(dropdown: true))
        ]
        Shared::SearchBar.new(label: t("ui.search.mode"), modes:, selected: "local")
      end

      def film_collection_search
        context = { view: @view, ratings: @ratings.presence }.compact
        fields = [ [ :view, @view ], *@ratings.map { |rating| [ "ratings[]", rating ] } ]
        Shared::CollectionSearchForm.new(path: library_path, clear_path: library_path(**context),
          context: fields, label: t("library.browser.search.#{@view}"), query: @query,
          input_id: "library-collection-query", frame: RESULTS_FRAME, css_class: "library-collection-search")
      end
    end
  end
end
