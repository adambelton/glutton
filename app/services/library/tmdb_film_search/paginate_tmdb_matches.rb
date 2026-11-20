module Library
  module TmdbFilmSearch
    class PaginateTmdbMatches
      PAGE_SIZE = 5
      LAST_PROVIDER_PAGE = 500
      PROVIDER_PAGE_BUDGET = 10
      Cursor = Data.define(:page, :offset)
      Page = Data.define(:candidates, :start, :next_cursor)

      def initialize(&search)
        @search = search
        @pages = {}
      end

      def call(cursor:, backwards:, legacy_batch:)
        cursor = legacy_start(cursor.page, legacy_batch) if legacy_batch.present?
        start = backwards ? previous_start(cursor) : cursor
        page, offset = start.deconstruct
        candidates = []
        loop do
          break unless (result = provider_page(page)).present?

          matches = result.fetch(:candidates)
          matches.drop(offset).each_with_index do |candidate, index|
            if candidates.size == PAGE_SIZE
              return Page.new(candidates:, start:, next_cursor: Cursor.new(page, offset + index))
            end
            candidates << candidate
          end
          return Page.new(candidates:, start:, next_cursor: nil) if page >= last_page(result)

          page += 1
          offset = 0
        end
        Page.new(candidates:, start:, next_cursor: Cursor.new(page, offset))
      end

      private

      def legacy_start(page, batch)
        count = provider_page(page).fetch(:candidates).size
        last_offset = ([ count - 1, 0 ].max / PAGE_SIZE) * PAGE_SIZE
        offset = batch == "last" ? last_offset : [ (batch.to_i - 1) * PAGE_SIZE, last_offset ].min
        Cursor.new(page, offset)
      end

      def previous_start(cursor)
        page, offset = cursor.deconstruct
        remaining = PAGE_SIZE
        loop do
          result = provider_page(page)
          break unless result.present?

          count = result.fetch(:candidates).size
          available = offset.nil? ? count : [ offset, count ].min
          return Cursor.new(page, available - remaining) if available >= remaining
          return Cursor.new(1, 0) if page == 1

          remaining -= available
          page -= 1
          offset = nil
        end
        Cursor.new(page + 1, 0)
      end

      def provider_page(page)
        return @pages.fetch(page) if @pages.key?(page)
        return if @pages.size >= PROVIDER_PAGE_BUDGET

        @pages[page] = @search.call(page)
      end

      def last_page(result)
        [ result.fetch(:total_pages), LAST_PROVIDER_PAGE ].min
      end
    end
  end
end
