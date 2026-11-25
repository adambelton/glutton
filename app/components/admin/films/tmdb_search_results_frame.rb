module Admin
  module Films
    class TmdbSearchResultsFrame < Shared::Base
      FRAME_ID = "admin-tmdb-film-results"

      def initialize(query:, result:, error:, catalogue_context:)
        @query, @result, @error, @catalogue_context = query, result, error, catalogue_context
      end

      def view_template
        tag(:turbo_frame, id: FRAME_ID, aria: { live: "polite" }, data: { admin_tmdb_search_target: "results" }) do
          if @result.present? || @error.present?
            render Shared::FilmSearchDropdown.new(css_class: "admin-tmdb-results", aria: { label: t("admin.tmdb.results") },
              data: { tmdb_query: @query }) do
              empty_message = t("admin.tmdb.empty") if @result.present? && @result.fetch(:candidates).empty?
              render Shared::FilmSearchResultsPanel.new(error: @error, empty_message:) do
                @result.fetch(:candidates).each { |candidate| film_result(candidate) }
              end
              pagination if @result.present?
            end
          end
        end
      end

      private

      def film_result(candidate)
        tmdb_id = candidate.fetch(:tmdb_id)
        film_id = @result.fetch(:registry_ids)[tmdb_id]
        render Shared::TmdbFilmSearchResultRow.new(candidate:) do
          if film_id.present?
            render RubyUI::Link.new(href: admin_film_path(film_id), variant: :ghost, size: :sm,
              aria: { label: t("admin.tmdb.record", title: candidate.fetch(:title)) }, data: { turbo_frame: "_top" }) do
              t("admin.tmdb.present")
            end
          else
            render Shared::ActionForm.new(url: admin_import_tmdb_film_path,
              params: selection_params(tmdb_id),
              data: { turbo_frame: "_top", action: "submit->admin-tmdb-search#useCatalogueContext" }) do
              render Shared::PrimaryButton.new(type: :submit, size: :sm) { t("admin.tmdb.add") }
            end
          end
        end
      end

      def selection_params(tmdb_id)
        batch = @result.fetch(:batch)
        { q: "", page: 1 }.merge(@catalogue_context, tmdb_id:, tmdb_query: @query, tmdb_page: @result.fetch(:page),
          tmdb_batch: (batch if batch > 1)).compact
      end

      def pagination
        page = @result.fetch(:page)
        total_pages = [ @result.fetch(:total_pages), 500 ].min
        batch = @result.fetch(:batch)
        batch_count = @result.fetch(:batch_count)
        previous = if batch > 1
          page_path(page, batch - 1)
        elsif page > 1
          page_path(page - 1, "last")
        end
        following = if batch < batch_count
          page_path(page, batch + 1)
        elsif page < total_pages
          page_path(page + 1)
        end
        current, total = batch_count > 1 ? [ batch, batch_count ] : [ page, [ page, total_pages ].max ]
        render Shared::FilmSearchPagination.new(page: current, total:,
          previous: ({ href: previous } if previous.present?), next_page: ({ href: following } if following.present?))
      end

      def page_path(page, batch = 1)
        tmdb_search_admin_films_path(**@catalogue_context, tmdb_query: @query, tmdb_page: page, tmdb_batch: (batch unless batch == 1))
      end
    end
  end
end
