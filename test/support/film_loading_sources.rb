require_relative "quality_assessment_sources"
require_relative "tmdb_http"

module FilmLoadingSources
  include QualityAssessmentSources

  class Sources
    attr_reader :source_requests, :assessment_requests

    class Http < TmdbHttp::Connection
      def initialize(sources:)
        super(response: nil)
        @sources = sources
      end

      def request(request)
        @requests << request
        payload = JSON.parse(request.body)
        response = @sources.assess(payload:)
        yield TmdbHttp::Response.new(code: 200, body: response.to_json)
      end
    end

    def initialize(context_builder:, zero_ids: [], import_failure_ids: [], wikipedia_failure_ids: [], assessment_failure_ids: [], unexpected_ids: [], tracer_provider: nil)
      @context_builder, @zero_ids, @import_failure_ids = context_builder, zero_ids, import_failure_ids
      @wikipedia_failure_ids, @assessment_failure_ids, @unexpected_ids = wikipedia_failure_ids, assessment_failure_ids, unexpected_ids
      @tracer_provider = tracer_provider
      @source_requests, @assessment_requests = [], []
      http = Http.new(sources: self)
      @type_safe_client_class = Class.new do
        define_singleton_method(:new) do |**limits|
          Registry::TypeSafeClient.new(token: "private-loading-test-key", http_class: http, **limits)
        end
      end
    end

    def movie(tmdb_id:)
      source_request(:tmdb, tmdb_id:)
      raise Registry::TmdbUnavailable.new(reason: :timeout) if @import_failure_ids.include?(tmdb_id)
      { "id" => tmdb_id, "title" => "Loading fixture #{tmdb_id}" }
    end

    def external_ids(tmdb_id:)
      source_request(:external_ids, tmdb_id:)
      { "id" => tmdb_id, "wikidata_id" => "Q#{tmdb_id}" }
    end

    def wikipedia_title(wikidata_id:)
      source_request(:wikidata, tmdb_id: wikidata_id.delete_prefix("Q").to_i)
      "Loading fixture #{wikidata_id}"
    end

    def context(title:, wikidata_id:, tmdb_id:)
      source_request(:wikipedia, tmdb_id:)
      raise Registry::ImportIncomplete.new(stage: :wikipedia, reason: :missing_article) if @wikipedia_failure_ids.include?(tmdb_id)
      @context_builder.call(tmdb_id:, wikidata_id:)
    end

    def assess(payload:)
      outside_transaction!
      tmdb_id = payload.fetch("state").fetch("film_title").split.last.to_i
      film = Registry::Film.find_by!(tmdb_id:)
      raise "Assessment started without source context" unless film.has_source_context?
      @assessment_requests << { tmdb_id:, payload: }
      raise Net::ReadTimeout.new("private-loading-test-key private-provider-body") if @assessment_failure_ids.include?(tmdb_id)
      raise "private-loading-test-key private-provider-body" if @unexpected_ids.include?(tmdb_id)
      client = QualityAssessmentSources::Client.new(default_support: @zero_ids.include?(tmdb_id) ? 0.1 : 0.7)
      client.answer(state: payload.fetch("state"), questions: payload.fetch("questions"), phase: "fake-http")
    end

    def call(tmdb_id:, maximum_requests:, maximum_cost_usd:)
      Registry::LoadFilm.call(tmdb_id:, maximum_requests:, maximum_cost_usd:,
        tmdb_client: self, wikidata_client: self, wikipedia_client: self,
        type_safe_client_class: @type_safe_client_class, tracer_provider: @tracer_provider)
    end

    private

    def source_request(phase, tmdb_id:)
      outside_transaction!
      @source_requests << { phase:, tmdb_id: }
    end

    def outside_transaction!
      raise "Provider request inside transaction" if Registry::Film.connection.transaction_open?
    end
  end

  def loading_sources(**options)
    Sources.new(context_builder: method(:wikipedia_context), **options)
  end
end
