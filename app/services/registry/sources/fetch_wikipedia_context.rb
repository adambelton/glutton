module Registry
  module Sources
    class FetchWikipediaContext
      Source = Data.define(:wikidata_id, :wikipedia_context)

      def self.call(tmdb_id:, tmdb_client: TmdbClient, wikidata_client: WikidataClient, wikipedia_client: WikipediaClient)
        new(tmdb_id:, tmdb_client:, wikidata_client:, wikipedia_client:).call
      end

      def initialize(tmdb_id:, tmdb_client:, wikidata_client:, wikipedia_client:)
        @tmdb_id, @tmdb_client, @wikidata_client, @wikipedia_client = tmdb_id, tmdb_client, wikidata_client, wikipedia_client
      end

      def call
        wikidata_id = fetch_wikidata_id
        wikipedia_context = fetch_verified_revision(wikidata_id) if wikidata_id.present?
        Source.new(wikidata_id:, wikipedia_context: wikipedia_context || {})
      rescue Registry::Errors::ImportIncomplete, Errors::TmdbUnavailable, Errors::TmdbNotFound,
        Errors::TmdbConfigurationError, Errors::InvalidTmdbResponse
        Source.new(wikidata_id:, wikipedia_context: {})
      end

      private

      def fetch_wikidata_id
        return if @tmdb_id.nil?

        external_ids = @tmdb_client.external_ids(tmdb_id: @tmdb_id)
        return unless external_ids.is_a?(Hash) && external_ids["id"].is_a?(Integer) && external_ids["id"] == @tmdb_id

        wikidata_id = external_ids["wikidata_id"]
        wikidata_id if wikidata_id.is_a?(String) && wikidata_id.match?(/\AQ[1-9][0-9]*\z/)
      end

      def fetch_verified_revision(wikidata_id)
        title = @wikidata_client.wikipedia_title(wikidata_id:)
        context = @wikipedia_client.context(title:, wikidata_id:, tmdb_id: @tmdb_id)
        context if WikipediaContext.valid?(context, tmdb_id: @tmdb_id) && context["wikidata_id"] == wikidata_id
      end
    end
  end
end
