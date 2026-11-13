module Registry
  module Sources
    class SearchTmdbFilms
      HORROR_GENRE_ID = 27

      def self.call(query:, page: 1, primary_release_year: nil, genre_id: nil, client: TmdbClient)
        parameters = TmdbSearchParameters.normalize(query:, page:, primary_release_year:)
        payload = client.search(**parameters)
        unless payload.is_a?(Hash) && payload["results"].is_a?(Array) &&
            payload["page"].is_a?(Integer) && payload["page"] == page &&
            [ "total_pages", "total_results" ].all? { |key| payload[key].is_a?(Integer) && payload[key] >= 0 }
          raise Registry::Errors::InvalidTmdbResponse, "TMDB returned invalid search data"
        end

        candidates = payload["results"].map do |candidate|
          unless candidate.is_a?(Hash) && candidate["id"].is_a?(Integer) && candidate["id"].positive? &&
              candidate["title"].is_a?(String) && candidate["title"].present? &&
              [ "original_title", "original_language" ].all? { |key| candidate[key].nil? || candidate[key].is_a?(String) }
            raise Registry::Errors::InvalidTmdbResponse, "TMDB returned invalid search data"
          end
          genre_ids = candidate["genre_ids"]
          next if genre_id && (!genre_ids.is_a?(Array) || !genre_ids.include?(genre_id))

          poster_path = candidate["poster_path"]
          overview = candidate["overview"]
          { tmdb_id: candidate["id"], title: candidate["title"], original_title: candidate["original_title"],
            release_date: TmdbReleaseDate.parse(candidate["release_date"]), original_language: candidate["original_language"],
            poster_path: (poster_path if poster_path.is_a?(String)),
            overview: (overview.strip.presence if overview.is_a?(String)) }
        end.compact
        { page:, total_pages: payload["total_pages"], total_results: payload["total_results"], candidates: }
      end
    end
  end
end
