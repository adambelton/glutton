module FilmKnowledge
  class AssignInitialFilmQualities
    def self.call(film_id:, client: nil, tracer_provider: Rails.application.config.x.langfuse_tracer_provider)
      new(film_id:, client:, tracer_provider:).call
    end

    def initialize(film_id:, client:, tracer_provider:)
      @film_id, @tracer_provider = film_id, tracer_provider
      @tracer = (tracer_provider || OpenTelemetry::Trace::TracerProvider.new).tracer("glutton.film-knowledge", "1")
      @client = client || TypeSafeClient.new(tracer: @tracer)
    end

    def call
      film = Film.find(@film_id)
      raise AssignmentFailed.new(reason: :unready_film) unless film.has_source_context?
      raise AssignmentFailed.new(reason: :already_assigned) if film.has_film_qualities?
      source = { "title" => film.title, "tmdb_id" => film.tmdb_id, "tmdb_metadata" => film.tmdb_metadata,
        "wikidata_id" => film.wikidata_id, "wikipedia_context" => film.wikipedia_context }.deep_dup
      definitions, categories = capture_vocabulary
      result = nil
      @tracer.in_span("assign-initial-film-qualities", attributes: {
        "langfuse.trace.name" => "assign-initial-film-qualities",
        "langfuse.version" => InitialQualityAssessment::POLICY,
        "langfuse.observation.type" => "span",
        "langfuse.trace.tags" => [ "film-knowledge", "initial-assignment" ],
        "langfuse.environment" => Rails.env.to_s,
        "langfuse.observation.input" => { source:, definitions:, categories: }.to_json
      }, record_exception: false) do |root|
        assessment = InitialQualityAssessment.new(source:, definitions:, categories:,
          trace_id: (root.context.hex_trace_id if root.context.valid?))
        assessment_error = nil
        begin
          assessment.call(client: @client)
        rescue StandardError => error
          assessment_error = error
        end
        film_quality_eval = Film.transaction do
          FilmQualityEval.record!(film: Film.lock.find(@film_id), assessment:)
        end
        root.set_attribute("film_quality_eval_id", film_quality_eval.id)
        if assessment_error
          film_quality_eval.record_application_failure!(reason: assessment.result.fetch("error").fetch("reason"))
          raise assessment_error
        end
        begin
          assigned_film = Film.transaction do
            film = Film.lock.find(@film_id)
            # These short table locks also protect against vocabulary membership phantoms.
            Film.connection.execute("LOCK TABLE quality_categories, qualities IN SHARE MODE")
            unless capture_vocabulary == [ definitions, categories ]
              raise AssignmentFailed.new(reason: :stale_inputs)
            end
            film_quality_eval.apply_initial_qualities!
            film
          end
        rescue AssignmentFailed => error
          film_quality_eval.record_application_failure!(reason: error.reason)
          raise
        rescue StandardError
          film_quality_eval.record_application_failure!(reason: :persistence_error)
          raise
        end
        evaluation_output = film_quality_eval.output
        root.set_attribute("langfuse.observation.output", evaluation_output.except("source", "definitions", "categories", "calls").merge("film_id" => assigned_film.id, "film_quality_eval_id" => film_quality_eval.id).to_json)
        result = { film: assigned_film, film_qualities: assigned_film.film_qualities.to_a, film_quality_eval: }
      rescue StandardError
        root.status = OpenTelemetry::Trace::Status.error("Initial quality assignment failed")
        root.set_attribute("langfuse.observation.level", "ERROR")
        raise
      end
      result
    rescue ActiveRecord::RecordNotFound
      raise AssignmentFailed.new(reason: :film_missing), cause: nil
    ensure
      @tracer_provider&.force_flush(timeout: 5)
    end

    private

    def capture_vocabulary
      definitions = Quality.order(:id).map do |quality|
        if quality.match_rule.blank? || quality.not_sufficient.blank?
          raise AssignmentFailed.new(reason: :invalid_vocabulary)
        end
        { "id" => quality.id, "name" => quality.name, "quality_category_id" => quality.quality_category_id,
          "match_rule" => quality.match_rule, "not_sufficient" => quality.not_sufficient }
      end
      categories = QualityCategory.order(:id).map do |quality_category|
        { "id" => quality_category.id, "name" => quality_category.name, "maximum_qualities" => quality_category.maximum_qualities }
      end
      if definitions.empty? || definitions.any? { |definition| categories.none? { |category| category.fetch("id") == definition.fetch("quality_category_id") } }
        raise AssignmentFailed.new(reason: :invalid_vocabulary)
      end
      [ definitions, categories ]
    end
  end
end
