require "bigdecimal"

module Registry
  class LoadFilm
    def self.call(tmdb_id:, maximum_requests:, maximum_cost_usd:,
      tmdb_client: TmdbClient, wikidata_client: WikidataClient, wikipedia_client: WikipediaClient,
      type_safe_client_class: TypeSafeClient, tracer_provider: Rails.application.config.x.langfuse_tracer_provider)
      new(tmdb_id:, maximum_requests:, maximum_cost_usd:, tmdb_client:, wikidata_client:, wikipedia_client:,
        type_safe_client_class:, tracer_provider:).call
    end

    def initialize(tmdb_id:, maximum_requests:, maximum_cost_usd:, tmdb_client:, wikidata_client:, wikipedia_client:,
      type_safe_client_class:, tracer_provider:)
      @tmdb_id, @maximum_requests, @maximum_cost_usd = tmdb_id, maximum_requests, maximum_cost_usd
      @tmdb_client, @wikidata_client, @wikipedia_client = tmdb_client, wikidata_client, wikipedia_client
      @type_safe_client_class, @tracer_provider = type_safe_client_class, tracer_provider
    end

    def call
      validate_limits!
      raise InvalidFilmLoad.new(reason: :open_transaction) if Film.connection.transaction_open?

      film = ImportFilm.call(tmdb_id: @tmdb_id, tmdb_client: @tmdb_client,
        wikidata_client: @wikidata_client, wikipedia_client: @wikipedia_client)
      tracer = (@tracer_provider || OpenTelemetry::Trace::TracerProvider.new).tracer("glutton.registry", "1")
      client = @type_safe_client_class.new(tracer:, maximum_requests: @maximum_requests, maximum_cost_usd: @maximum_cost_usd, profile: :registry)
      result = AssignInitialFilmQualities.call(film_id: film.id, client:, tracer_provider: @tracer_provider)
      warnings = []
      if result.fetch(:film_qualities).empty?
        warning = { tmdb_id: @tmdb_id, film_id: film.id, reason: :no_qualities,
          message: I18n.t("registry.assignment.warnings.no_qualities", film_id: film.id) }
        Rails.logger.warn(warning.to_json)
        warnings << warning
      end
      result.merge(warnings:)
    end

    private

    def validate_limits!
      # These operator-supplied bounds are validated before any provider request.
      unless @maximum_requests.is_a?(Integer) && @maximum_requests.positive?
        raise InvalidFilmLoad.new(reason: :invalid_request_limit)
      end
      unless @maximum_cost_usd.is_a?(Numeric) && @maximum_cost_usd.real? && @maximum_cost_usd.finite? && @maximum_cost_usd.positive?
        raise InvalidFilmLoad.new(reason: :invalid_cost_limit)
      end
      @maximum_cost_usd = decimal_cost(@maximum_cost_usd)
    end

    def decimal_cost(cost)
      BigDecimal(cost.to_s)
    rescue ArgumentError
      raise InvalidFilmLoad.new(reason: :invalid_cost_limit), cause: nil
    end
  end
end
