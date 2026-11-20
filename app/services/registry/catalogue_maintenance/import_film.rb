module Registry
  module CatalogueMaintenance
    class ImportFilm
      extend Monitoring::Instrumentation
      instrument_operations :call

      def self.call(tmdb_id:, tmdb_client: Sources::TmdbClient,
        wikidata_client: Sources::WikidataClient, wikipedia_client: Sources::WikipediaClient)
        new(tmdb_id:, tmdb_client:, wikidata_client:, wikipedia_client:).call
      end

      def initialize(tmdb_id:, tmdb_client:, wikidata_client:, wikipedia_client:)
        @tmdb_id, @tmdb_client, @wikidata_client, @wikipedia_client = tmdb_id, tmdb_client, wikidata_client, wikipedia_client
      end

      def call
        raise Registry::Errors::InvalidTmdbId, "TMDB ID must be a positive Integer" unless @tmdb_id.is_a?(Integer) && @tmdb_id.positive?
        raise Registry::Errors::ImportIncomplete.new(stage: :persistence, reason: :existing_film) if Film.exists?(tmdb_id: @tmdb_id)

        tmdb_data = Sources::FetchTmdbFilm.call(tmdb_id: @tmdb_id, tmdb_client: @tmdb_client)
        source = Sources::FetchWikipediaContext.call(tmdb_id: @tmdb_id, tmdb_client: @tmdb_client,
          wikidata_client: @wikidata_client, wikipedia_client: @wikipedia_client)
        @film = Film.new(tmdb_id: @tmdb_id)
        Film.transaction(requires_new: true) do
          @film.import_with_available_sources!(tmdb_data:, wikidata_id: source.wikidata_id, wikipedia_context: source.wikipedia_context)
        end
      rescue Registry::Errors::ImportIncomplete => error
        raise Registry::Errors::ImportIncomplete.new(stage: error.stage, reason: error.reason, tmdb_id: @tmdb_id), cause: nil
      rescue ActiveRecord::RecordNotUnique => error
        constraint = error.cause&.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
        raise unless constraint == "index_films_on_tmdb_id"
        raise Registry::Errors::ImportIncomplete.new(stage: :persistence, reason: :existing_film, tmdb_id: @tmdb_id), cause: nil
      rescue ActiveRecord::RecordInvalid => error
        raise unless error.record.equal?(@film) && @film.errors.details == { tmdb_id: [ { error: :taken, value: @tmdb_id } ] }
        raise Registry::Errors::ImportIncomplete.new(stage: :persistence, reason: :existing_film, tmdb_id: @tmdb_id), cause: nil
      end
    end
  end
end
