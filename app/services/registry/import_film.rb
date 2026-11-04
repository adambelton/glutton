module Registry
  class ImportFilm
    def self.call(tmdb_id:, tmdb_client: TmdbClient, wikidata_client: WikidataClient, wikipedia_client: WikipediaClient)
      new(tmdb_id:, tmdb_client:, wikidata_client:, wikipedia_client:).call
    end

    def initialize(tmdb_id:, tmdb_client:, wikidata_client:, wikipedia_client:)
      @tmdb_id, @tmdb_client, @wikidata_client, @wikipedia_client = tmdb_id, tmdb_client, wikidata_client, wikipedia_client
    end

    def call
      raise InvalidTmdbId, "TMDB ID must be a positive Integer" unless @tmdb_id.is_a?(Integer) && @tmdb_id.positive?
      raise ImportIncomplete.new(stage: :persistence, reason: :existing_film) if Film.exists?(tmdb_id: @tmdb_id)

      tmdb_data = FetchTmdbFilm.call(tmdb_id: @tmdb_id, tmdb_client: @tmdb_client)
      wikipedia_context = FetchWikipediaContext.call(tmdb_id: @tmdb_id, tmdb_client: @tmdb_client,
        wikidata_client: @wikidata_client, wikipedia_client: @wikipedia_client)
      @film = Film.new(tmdb_id: @tmdb_id)
      Film.transaction(requires_new: true) { @film.import!(tmdb_data:, wikipedia_context:) }
    rescue ImportIncomplete => error
      raise ImportIncomplete.new(stage: error.stage, reason: error.reason, tmdb_id: @tmdb_id), cause: nil
    rescue ActiveRecord::RecordNotUnique => error
      constraint = error.cause&.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      raise unless constraint == "index_films_on_tmdb_id"
      raise ImportIncomplete.new(stage: :persistence, reason: :existing_film, tmdb_id: @tmdb_id), cause: nil
    rescue ActiveRecord::RecordInvalid => error
      raise unless error.record.equal?(@film) && @film.errors.details == { tmdb_id: [ { error: :taken, value: @tmdb_id } ] }
      raise ImportIncomplete.new(stage: :persistence, reason: :existing_film, tmdb_id: @tmdb_id), cause: nil
    end
  end
end
