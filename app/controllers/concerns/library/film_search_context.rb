module Library
  module FilmSearchContext
    private

    def valid_film_search?
      query = params[:query]
      page = params.fetch(:page, "1")
      query.is_a?(String) && query.valid_encoding? && (1..200).cover?(query.strip.length) &&
        page.is_a?(String) && page.match?(/\A[1-9]\d{0,2}\z/) && page.to_i <= 500 &&
        film_search_batch.is_a?(String) && film_search_batch.match?(/\A(?:[1-9]\d{0,2}|last)\z/)
    end

    def film_search_batch
      params.fetch(:batch, "1")
    end

    def film_search_page_number
      params.fetch(:page, "1").to_i
    end

    def film_search_results_path
      library_film_search_path(query: params[:query], page: film_search_page_number, batch: (film_search_batch unless film_search_batch == "1"))
    end

    def render_film_search_error(key, status)
      query = params[:query] if valid_film_search?
      render ::Views::Library::FilmSearch.new(query:, error: t("library.search.#{key}")), status:
    end
  end
end
