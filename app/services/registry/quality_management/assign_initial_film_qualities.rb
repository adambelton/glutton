module Registry
  module QualityManagement
    class AssignInitialFilmQualities
      extend Monitoring::Instrumentation
      instrument_operations :call

      TRACE_NAME = "assign-initial-film-qualities".freeze
      TRACE_TAGS = [ "registry", "initial-assignment" ].freeze

      def self.call(film_id:, client: nil, tracer_provider: ActivityMonitoring.ai_tracer_provider)
        new(film_id:, client:, tracer_provider:).call
      end

      def initialize(film_id:, client:, tracer_provider:)
        @film_id, @tracer_provider = film_id, tracer_provider
        @client = client || TypeSafeClient.new(tracer: ActivityMonitoring.ai_tracer(ActivityMonitoring::Scopes::REGISTRY, provider: tracer_provider), profile: :registry)
      end

      def call
        film = Film.find(@film_id)
        ActivityMonitoring.current_operation_span&.set_film_id(film.id)
        raise Errors::AssignmentFailed.new(reason: :unready_film) unless film.has_source_context?
        raise Errors::AssignmentFailed.new(reason: :already_assigned) if film.has_film_qualities?
        source = { "title" => film.title, "tmdb_id" => film.tmdb_id, "tmdb_metadata" => film.tmdb_metadata,
          "wikidata_id" => film.wikidata_id, "wikipedia_context" => film.wikipedia_context }.deep_dup
        definitions, categories = capture_vocabulary
        result = nil
        ActivityMonitoring.trace_ai_workflow(TRACE_NAME, scope: ActivityMonitoring::Scopes::REGISTRY, provider: @tracer_provider, tags: TRACE_TAGS,
          input: { source:, definitions:, categories: }) do |root|
          assessment = EvaluateInitialFilmQualities.new(source:, definitions:, categories:,
            trace_id: root.trace_id)
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
          raise assessment_error if assessment_error

          assigned_film = Film.transaction do
            film = Film.lock.find(@film_id)
            # These short table locks also protect against vocabulary membership phantoms.
            Film.connection.execute("LOCK TABLE quality_categories, qualities IN SHARE MODE")
            unless capture_vocabulary == [ definitions, categories ]
              raise Errors::AssignmentFailed.new(reason: :stale_inputs)
            end
            film.apply_initial_qualities!(evaluation: film_quality_eval)
            film
          end
          evaluation_output = film_quality_eval.output
          root.set_output(evaluation_output.except("source", "definitions", "categories", "calls").merge("film_id" => assigned_film.id, "film_quality_eval_id" => film_quality_eval.id))
          result = { film: assigned_film, film_qualities: assigned_film.film_qualities.to_a, film_quality_eval: }
        end
        result
      rescue ActiveRecord::RecordNotFound
        raise Errors::AssignmentFailed.new(reason: :film_missing), cause: nil
      end

      private

      def capture_vocabulary
        definitions = Quality.order(:id).map do |quality|
          if quality.match_rule.blank? || quality.not_sufficient.blank?
            raise Errors::AssignmentFailed.new(reason: :invalid_vocabulary)
          end
          { "id" => quality.id, "name" => quality.name, "quality_category_id" => quality.quality_category_id,
            "match_rule" => quality.match_rule, "not_sufficient" => quality.not_sufficient }
        end
        categories = QualityCategory.order(:id).map do |quality_category|
          { "id" => quality_category.id, "name" => quality_category.name, "maximum_qualities" => quality_category.maximum_qualities }
        end
        if definitions.empty? || definitions.any? { |definition| categories.none? { |category| category.fetch("id") == definition.fetch("quality_category_id") } }
          raise Errors::AssignmentFailed.new(reason: :invalid_vocabulary)
        end
        [ definitions, categories ]
      end
    end
  end
end
