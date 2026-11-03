module FilmKnowledge
  class FetchTmdbFilm
    def self.call(tmdb_id:, tmdb_client: TmdbClient)
      new(tmdb_id:, tmdb_client:).call
    end

    def initialize(tmdb_id:, tmdb_client:)
      @tmdb_id, @tmdb_client = tmdb_id, tmdb_client
    end

    def call
      raise InvalidTmdbId, "TMDB ID must be a positive Integer" unless @tmdb_id.is_a?(Integer) && @tmdb_id.positive?
      fetch_metadata
    rescue TmdbUnavailable => error
      raise ImportIncomplete.new(stage: :tmdb, reason: error.reason, tmdb_id: @tmdb_id), cause: nil
    rescue TmdbNotFound
      raise ImportIncomplete.new(stage: :tmdb, reason: :not_found, tmdb_id: @tmdb_id), cause: nil
    rescue TmdbConfigurationError
      raise ImportIncomplete.new(stage: :tmdb, reason: :configuration, tmdb_id: @tmdb_id), cause: nil
    rescue InvalidTmdbResponse
      raise ImportIncomplete.new(stage: :tmdb, reason: :invalid_response, tmdb_id: @tmdb_id), cause: nil
    end

    private

    def fetch_metadata
      payload = @tmdb_client.movie(tmdb_id: @tmdb_id)
      unless payload.is_a?(Hash) && payload["id"].is_a?(Integer) && payload["id"] == @tmdb_id &&
          payload["title"].is_a?(String) && payload["title"].present? &&
          (payload["original_title"].nil? || payload["original_title"].is_a?(String))
        raise InvalidTmdbResponse, "TMDB returned invalid movie data"
      end
      date = TmdbReleaseDate.parse(payload["release_date"])
      tmdb_metadata = { "fetched_at" => Time.current.utc.iso8601, "language" => "en-US", "details" => TmdbMetadata.from(payload) }
      tmdb_metadata["original_title"] = payload["original_title"] unless payload["original_title"].nil?
      { title: payload.fetch("title"), release_date: date, tmdb_metadata: }
    end
  end
end
