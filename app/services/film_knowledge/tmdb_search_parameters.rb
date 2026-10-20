module FilmKnowledge
  class TmdbSearchParameters
    def self.normalize(query:, page:, primary_release_year:)
      unless query.is_a?(String) && query.valid_encoding? && query.strip.present? && query.strip.length <= 200 &&
          page.is_a?(Integer) && (1..500).cover?(page) &&
          (primary_release_year.nil? || (primary_release_year.is_a?(Integer) && (1000..9999).cover?(primary_release_year)))
        raise InvalidTmdbSearch, "Invalid TMDB search parameters"
      end

      { query: query.strip, page:, primary_release_year: }
    end
  end
end
