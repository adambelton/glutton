require "bigdecimal"

module Registry
  class LoadFilms
    def self.call(tmdb_ids:, maximum_films:, maximum_requests_per_film:, maximum_cost_usd_per_film:, maximum_cost_usd:,
      film_loader: LoadFilm)
      new(tmdb_ids:, maximum_films:, maximum_requests_per_film:, maximum_cost_usd_per_film:, maximum_cost_usd:, film_loader:).call
    end

    def initialize(tmdb_ids:, maximum_films:, maximum_requests_per_film:, maximum_cost_usd_per_film:, maximum_cost_usd:, film_loader:)
      @tmdb_ids, @maximum_films = tmdb_ids, maximum_films
      @maximum_requests_per_film, @maximum_cost_usd_per_film = maximum_requests_per_film, maximum_cost_usd_per_film
      @maximum_cost_usd, @film_loader = maximum_cost_usd, film_loader
    end

    def call
      limits = validate_limits!
      raise InvalidFilmLoad.new(reason: :open_transaction) if Film.connection.transaction_open?

      loaded_film_ids, warnings = [], []
      @tmdb_ids.each do |tmdb_id|
        begin
          result = @film_loader.call(tmdb_id:, maximum_requests: @maximum_requests_per_film,
            maximum_cost_usd: @maximum_cost_usd_per_film)
          warnings.concat(result.fetch(:warnings))
          loaded_film_ids << result.fetch(:film).id if result.fetch(:film_qualities).any?
        rescue ImportIncomplete => error
          warnings << report_failure(tmdb_id:, reason: :import_failed, detail: error.message,
            failure_reason: error.reason, stage: error.stage)
        rescue AssignmentFailed => error
          warnings << report_failure(tmdb_id:, reason: :assessment_failed, detail: error.message, failure_reason: error.reason)
        rescue StandardError
          warnings << report_failure(tmdb_id:, reason: :unexpected_failure)
        end
      end
      { loaded_film_ids:, warnings:, limits: }
    end

    private

    def validate_limits!
      # The entire external list and its budget are checked before loading the first film.
      raise InvalidFilmLoad.new(reason: :invalid_tmdb_ids) unless @tmdb_ids.is_a?(Array)
      @tmdb_ids = @tmdb_ids.dup.freeze
      unless @tmdb_ids.any? && @tmdb_ids.all? { |tmdb_id| tmdb_id.is_a?(Integer) && tmdb_id.positive? }
        raise InvalidFilmLoad.new(reason: :invalid_tmdb_ids)
      end
      unless @maximum_films.is_a?(Integer) && @maximum_films.positive? && @tmdb_ids.size <= @maximum_films
        raise InvalidFilmLoad.new(reason: :invalid_film_limit)
      end
      unless @maximum_requests_per_film.is_a?(Integer) && @maximum_requests_per_film.positive?
        raise InvalidFilmLoad.new(reason: :invalid_request_limit)
      end
      unless [ @maximum_cost_usd_per_film, @maximum_cost_usd ].all? { |cost| cost.is_a?(Numeric) && cost.real? && cost.finite? && cost.positive? }
        raise InvalidFilmLoad.new(reason: :invalid_cost_limit)
      end
      maximum_cost = decimal_cost(@maximum_cost_usd_per_film) * @tmdb_ids.size
      raise InvalidFilmLoad.new(reason: :batch_budget_exceeded) if maximum_cost > decimal_cost(@maximum_cost_usd)

      { films: @tmdb_ids.size, maximum_requests: @maximum_requests_per_film * @tmdb_ids.size, maximum_cost_usd: maximum_cost }
    end

    def decimal_cost(cost)
      BigDecimal(cost.to_s)
    rescue ArgumentError
      raise InvalidFilmLoad.new(reason: :invalid_cost_limit), cause: nil
    end

    def report_failure(tmdb_id:, reason:, detail: nil, **context)
      warning = { tmdb_id:, film_id: Film.find_by(tmdb_id:)&.id, reason:,
        message: I18n.t("registry.loading.warnings.#{reason}", tmdb_id:, detail:) }.merge(context)
      Rails.logger.warn(warning.to_json)
      warning
    end
  end
end
