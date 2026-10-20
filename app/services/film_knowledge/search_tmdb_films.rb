module FilmKnowledge
  class SearchTmdbFilms
    def self.call(query:, page: 1, primary_release_year: nil, client: TmdbClient)
      query = TmdbClient.validate_search!(query:, page:, primary_release_year:)
      payload = client.search(query:, page:, primary_release_year:)
      unless payload.is_a?(Hash) && payload["results"].is_a?(Array) &&
          payload["page"].is_a?(Integer) && payload["page"] == page &&
          [ "total_pages", "total_results" ].all? { |key| payload[key].is_a?(Integer) && payload[key] >= 0 }
        raise InvalidTmdbResponse, "TMDB returned invalid search data"
      end

      candidates = payload["results"].map do |candidate|
        unless candidate.is_a?(Hash) && candidate["id"].is_a?(Integer) && candidate["id"].positive? &&
            candidate["title"].is_a?(String) && candidate["title"].present? &&
            [ "original_title", "original_language" ].all? { |key| candidate[key].nil? || candidate[key].is_a?(String) }
          raise InvalidTmdbResponse, "TMDB returned invalid search data"
        end
        date = candidate["release_date"]
        unless date.nil? || date == ""
          unless date.is_a?(String) && date.match?(/\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/)
            raise InvalidTmdbResponse, "TMDB returned an invalid release date"
          end
          begin
            date = Date.iso8601(date)
          rescue Date::Error
            raise InvalidTmdbResponse, "TMDB returned an invalid release date", cause: nil
          end
        end
        { tmdb_id: candidate["id"], title: candidate["title"], original_title: candidate["original_title"],
          release_date: date.presence, original_language: candidate["original_language"] }
      end
      { page:, total_pages: payload["total_pages"], total_results: payload["total_results"], candidates: }
    end
  end
end
