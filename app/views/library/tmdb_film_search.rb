module Views
  module Library
    class TmdbFilmSearch < ::Views::Base
      def initialize(query:, number: 1, result: nil, error: nil)
        @query, @number, @result, @error = query, number, result, error
      end

      def view_template
        page(title: t("library.browser.title"), heading_outside_card: true,
          heading_action: ::Library::TmdbFilmSearchForm.new(query: @query),
          back_to: library_path, back_label: t("library.browser.return")) do
          section(id: "library-film-search-results", aria: { live: "polite" }) do
            empty_message = t("library.search.empty") if @result&.candidates&.empty?
            render Shared::FilmSearchResultsPanel.new(error: @error, empty_message:) do
              @result.candidates.each { |candidate| search_result(candidate) }
            end
            pagination if @result.present?
          end
          render ::Library::ActionConfirmationDialog.new if @result.present?
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
        render Shared::TmdbFilmSearchResultRow.new(candidate:, icon_actions: true) do
          tooltip_text = t("library.detail.add_to_watchlist")
          render ::Library::FilmActionForm.new(url: library_tmdb_search_watchlist_path, params: selection, action_label: tooltip_text, film_title: candidate.fetch(:title),
            data: { library_tmdb_selection: true }) do
            render Shared::IconButton.new(type: :submit, variant: :ghost, size: :xl, class: "ui-action-button",
              aria: { label: tooltip_text }, data: { tooltip: tooltip_text }) { render ::Library::BookmarkPlusIcon.new }
          end

          tooltip_text = t("library.detail.add_to_watched")
          render ::Library::FilmActionForm.new(url: library_tmdb_search_watched_path, params: selection, action_label: tooltip_text, film_title: candidate.fetch(:title),
            data: { library_tmdb_selection: true }) do
            render Shared::IconButton.new(type: :submit, variant: :ghost, size: :xl, class: "ui-action-button",
              aria: { label: tooltip_text }, data: { tooltip: tooltip_text }) { render ::Library::EyeCheckIcon.new }
          end
        end
      end

      def pagination
        previous = if @number > 1
          library_tmdb_film_search_path(**search_parameters(@result.start, @number - 1), backwards: 1)
        end
        following = if @result.next_cursor.present?
          library_tmdb_film_search_path(**search_parameters(@result.next_cursor, @number + 1))
        end
        render Shared::FilmSearchPagination.new(page: @number,
          previous: ({ href: previous } if previous.present?), next_page: ({ href: following } if following.present?))
      end

      def search_parameters(cursor, number)
        { query: @query, page: cursor.page, offset: (cursor.offset if cursor.offset.positive?), number: (number if number > 1) }.compact
      end
    end
  end
end
