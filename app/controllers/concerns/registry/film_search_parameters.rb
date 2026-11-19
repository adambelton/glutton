module Registry
  module FilmSearchParameters
    private

    def validate_tmdb_parameters
      query = params.fetch(:tmdb_query, "")
      page = params.fetch(:tmdb_page, "1")
      batch = params.fetch(:tmdb_batch, "1")
      unless query.is_a?(String) && query.valid_encoding? && query.strip.length <= 200 &&
          page.is_a?(String) && page.match?(/\A[1-9]\d{0,2}\z/) && page.to_i <= 500 &&
          batch.is_a?(String) && batch.match?(/\A(?:[1-9]\d{0,2}|last)\z/)
        render ::Views::Admin::Message.new(key: :invalid), status: :bad_request
        return
      end
      @tmdb_query, @tmdb_page, @tmdb_batch = query.strip, page.to_i, batch
    end

    def catalogue_context
      { q: @query.presence, page: (@page_number if @page_number > 1) }.compact
    end
  end
end
