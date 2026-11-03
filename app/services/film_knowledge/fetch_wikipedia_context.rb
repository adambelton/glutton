module FilmKnowledge
  class FetchWikipediaContext
    def self.call(tmdb_id:, tmdb_client: TmdbClient, wikidata_client: WikidataClient, wikipedia_client: WikipediaClient)
      new(tmdb_id:, tmdb_client:, wikidata_client:, wikipedia_client:).call
    end

    def initialize(tmdb_id:, tmdb_client:, wikidata_client:, wikipedia_client:)
      @tmdb_id, @tmdb_client, @wikidata_client, @wikipedia_client = tmdb_id, tmdb_client, wikidata_client, wikipedia_client
    end

    def call
      fetch_context
    rescue ImportIncomplete => error
      raise ImportIncomplete.new(stage: error.stage, reason: error.reason, tmdb_id: @tmdb_id), cause: nil
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

    def fetch_context
      raise ImportIncomplete.new(stage: :tmdb, reason: :missing_identity) if @tmdb_id.nil?
      external_ids = @tmdb_client.external_ids(tmdb_id: @tmdb_id)
      unless external_ids.is_a?(Hash) && external_ids["id"].is_a?(Integer) && external_ids["id"] == @tmdb_id
        raise ImportIncomplete.new(stage: :tmdb, reason: :invalid_response)
      end
      wikidata_id = external_ids["wikidata_id"]
      unless wikidata_id.is_a?(String) && wikidata_id.match?(/\AQ[1-9][0-9]*\z/)
        raise ImportIncomplete.new(stage: :tmdb, reason: :missing_identity)
      end
      title = @wikidata_client.wikipedia_title(wikidata_id:)
      @wikipedia_client.context(title:, wikidata_id:, tmdb_id: @tmdb_id)
    end
  end
end
