module Views
  module Library
    class FilmSearch < ::Views::Base
      def initialize(query:, page_number: 1, result: nil, error: nil)
        @query, @page_number, @result, @error = query, page_number, result, error
      end

      def view_template
        page(title: t("library.browser.title"), heading_outside_card: true,
          heading_action: ::Library::FilmSearchForm.new(query: @query)) do
          text_link(t("library.browser.return"), library_path)
          section(id: "library-film-search-results", aria: { live: "polite" }) do
            div(class: "library-film-search-content") do
              h2 { t("library.search.results") }
              if @error.present?
                p(role: "alert") { @error }
              elsif @result.candidates.empty?
                p { t("library.search.empty") }
              else
                ul(class: "library-film-search-results") do
                  @result.candidates.each { |candidate| search_result(candidate) }
                end
              end
            end
            pagination if @result.present?
          end
        end
      end

      private

      def search_result(candidate)
        tmdb_id = candidate.fetch(:tmdb_id)
        title = candidate.fetch(:title)
        entry = @result.entries[tmdb_id]
        selection = { tmdb_id:, query: @query, page: @page_number, batch: @result.batch }
        li do
          render ::Registry::FilmPoster.new(title:, path: candidate.fetch(:poster_path), placeholder: :wordmark)
          div(class: "library-film-search-result-body") do
            div(class: "library-film-search-result-details") do
              h3 { render ::Registry::FilmTitle.new(title:, release_date: candidate.fetch(:release_date)) }
              overview = candidate.fetch(:overview)
              p(class: "library-film-search-overview") { overview } if overview.present?
              if entry.present?
                p { t(entry.watched? ? "library.search.in_watched" : "library.search.in_watchlist") }
              end
            end
            div(class: "library-film-search-actions") do
              unless entry.present?
                tooltip_text = t("library.detail.add_to_watchlist")
                render Shared::ActionForm.new(url: library_search_watchlist_path, params: selection) do
                  render Shared::IconButton.new(type: :submit, variant: :ghost, size: :xl, class: "ui-action-button",
                    aria: { label: tooltip_text }, data: { tooltip: tooltip_text }) { render ::Library::BookmarkPlusIcon.new }
                end
              end
              if entry.nil?
                tooltip_text = t("library.detail.add_to_watched")
                render Shared::ActionForm.new(url: library_search_watched_path, params: selection) do
                  render Shared::IconButton.new(type: :submit, variant: :ghost, size: :xl, class: "ui-action-button",
                    aria: { label: tooltip_text }, data: { tooltip: tooltip_text }) { render ::Library::EyeCheckIcon.new }
                end
              elsif entry.can_move_to_watched?
                tooltip_text = t("library.detail.move_to_watched")
                render Shared::ActionForm.new(url: library_search_move_to_watched_path, params: selection.except(:tmdb_id).merge(library_film_id: entry.id)) do
                  render Shared::IconButton.new(type: :submit, variant: :ghost, size: :xl, class: "ui-action-button",
                    aria: { label: tooltip_text }, data: { tooltip: tooltip_text }) { render ::Library::EyeCheckIcon.new }
                end
              end
            end
          end
        end
      end

      def pagination
        nav(class: "library-pagination", aria: { label: t("library.browser.pagination") }) do
          if @result.batch > 1
            text_link(t("library.browser.previous"), search_path(page: @page_number, batch: @result.batch - 1))
          elsif @page_number > 1
            text_link(t("library.browser.previous"), search_path(page: @page_number - 1, batch: "last"))
          end
          span do
            if @result.batch_count > 1
              t("library.search.page", number: @result.batch, total: @result.batch_count)
            else
              t("library.search.page", number: @page_number, total: [ @result.total_pages, @page_number ].max)
            end
          end
          if @result.batch < @result.batch_count
            text_link(t("library.browser.next"), search_path(page: @page_number, batch: @result.batch + 1))
          elsif @page_number < @result.total_pages
            text_link(t("library.browser.next"), search_path(page: @page_number + 1))
          end
        end
      end

      def search_path(page:, batch: nil)
        library_film_search_path(query: @query, page:, batch:)
      end
    end
  end
end
