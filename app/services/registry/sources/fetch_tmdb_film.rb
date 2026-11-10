module Registry
  module Sources
    class FetchTmdbFilm
      def self.call(tmdb_id:, tmdb_client: TmdbClient)
        new(tmdb_id:, tmdb_client:).call
      end

      def initialize(tmdb_id:, tmdb_client:)
        @tmdb_id, @tmdb_client = tmdb_id, tmdb_client
      end

      def call
        raise Registry::Errors::InvalidTmdbId, "TMDB ID must be a positive Integer" unless @tmdb_id.is_a?(Integer) && @tmdb_id.positive?
        fetch_metadata
      rescue Errors::TmdbUnavailable => error
        raise Registry::Errors::ImportIncomplete.new(stage: :tmdb, reason: error.reason, tmdb_id: @tmdb_id), cause: nil
      rescue Errors::TmdbNotFound
        raise Registry::Errors::ImportIncomplete.new(stage: :tmdb, reason: :not_found, tmdb_id: @tmdb_id), cause: nil
      rescue Errors::TmdbConfigurationError
        raise Registry::Errors::ImportIncomplete.new(stage: :tmdb, reason: :configuration, tmdb_id: @tmdb_id), cause: nil
      rescue Registry::Errors::InvalidTmdbResponse
        raise Registry::Errors::ImportIncomplete.new(stage: :tmdb, reason: :invalid_response, tmdb_id: @tmdb_id), cause: nil
      end

      private

      def fetch_metadata
        payload = @tmdb_client.movie(tmdb_id: @tmdb_id)
        unless payload.is_a?(Hash) && payload["id"].is_a?(Integer) && payload["id"] == @tmdb_id &&
            payload["title"].is_a?(String) && payload["title"].present?
          raise Registry::Errors::InvalidTmdbResponse, "TMDB returned invalid movie data"
        end
        date = TmdbReleaseDate.parse(payload["release_date"])
        tmdb_metadata = { "fetched_at" => Time.current.utc.iso8601, "language" => "en-US", "details" => payload.as_json }
        { title: payload.fetch("title"), release_date: date, tmdb_metadata: }
      end
    end
  end
end
