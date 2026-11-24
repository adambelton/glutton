module Views
  module Library
    class TmdbFilmSearch < ::Views::Base
      def initialize(query:, number: 1, result: nil, error: nil)
        @query, @number, @result, @error = query, number, result, error
      end

      def view_template
        page(title: t("library.browser.title"), heading_outside_card: true,
          heading_action: ::Library::TmdbFilmSearchForm.new(query: @query)) do
          text_link(t("library.browser.return"), library_path)
          section(id: "library-film-search-results", aria: { live: "polite" }) do
            empty_message = t("library.search.empty") if @result&.candidates&.empty?
            render Shared::TmdbFilmSearchResultsPanel.new(error: @error, empty_message:) do
              @result.candidates.each { |candidate| search_result(candidate) }
            end
            pagination if @result.present?
          end
        end
      end

      private

      def search_result(candidate)
        tmdb_id = candidate.fetch(:tmdb_id)
        library_film = @result.entries[tmdb_id]
        if library_film.present?
          status = t(library_film.watched? ? "library.search.in_watched" : "library.search.in_watchlist")
          return render Shared::TmdbFilmSearchResultRow.new(candidate:, status:)
        end

        selection = search_parameters(@result.start, @number).merge(tmdb_id:)
        render Shared::TmdbFilmSearchResultRow.new(candidate:) do
          tooltip_text = t("library.detail.add_to_watchlist")
          render Shared::ActionForm.new(url: library_tmdb_search_watchlist_path, params: selection,
            data: { library_tmdb_selection: true }) do
            render Shared::IconButton.new(type: :submit, variant: :ghost, size: :xl, class: "ui-action-button",
              aria: { label: tooltip_text }, data: { tooltip: tooltip_text }) { render ::Library::BookmarkPlusIcon.new }
          end

          tooltip_text = t("library.detail.add_to_watched")
          render Shared::ActionForm.new(url: library_tmdb_search_watched_path, params: selection,
            data: { library_tmdb_selection: true }) do
            render Shared::IconButton.new(type: :submit, variant: :ghost, size: :xl, class: "ui-action-button",
              aria: { label: tooltip_text }, data: { tooltip: tooltip_text }) { render ::Library::EyeCheckIcon.new }
          end
        end
      end

      def pagination
        nav(class: "library-pagination", aria: { label: t("library.browser.pagination") }) do
          if @number > 1
            text_link(t("library.browser.previous"), library_tmdb_film_search_path(**search_parameters(@result.start, @number - 1), backwards: 1))
          end
          span { t("library.browser.page", number: @number) }
          if @result.next_cursor.present?
            text_link(t("library.browser.next"), library_tmdb_film_search_path(**search_parameters(@result.next_cursor, @number + 1)))
          end
        end
      end

      def search_parameters(cursor, number)
        { query: @query, page: cursor.page, offset: (cursor.offset if cursor.offset.positive?), number: (number if number > 1) }.compact
      end
    end
  end
end
