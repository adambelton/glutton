module Ratings
  class RefreshExpressionProfile
    TRACE_NAME = "refresh-expression-profile".freeze
    TRACE_TAGS = [ "ratings", "expression-profile" ].freeze

    def self.call(user_id:, synthesizer:, tracer_provider: Rails.application.config.x.langfuse_tracer_provider)
      new(user_id:, synthesizer:, tracer_provider:).call
    end

    def initialize(user_id:, synthesizer:, tracer_provider:)
      @user_id, @synthesizer, @tracer_provider = user_id, synthesizer, tracer_provider
      @tracer = (tracer_provider || OpenTelemetry::Trace::TracerProvider.new).tracer("glutton.ratings", "1")
    end

    def call
      current, evidence = with_owner_lock { |user| [ ExpressionProfile.find_by(user:)&.current_revision, capture_evidence ] }
      expression_texts = texts_by_film(evidence)
      return current if expression_texts == texts_by_film(current&.expression_texts || [])

      @tracer.in_span(TRACE_NAME, attributes: {
        "langfuse.trace.name" => TRACE_NAME,
        "langfuse.trace.tags" => TRACE_TAGS,
        "langfuse.environment" => Rails.env.to_s,
        "langfuse.observation.type" => "span",
        "langfuse.observation.input" => { expression_count: evidence.size }.to_json
      }, record_exception: false) do |span|
        assessment = ExpressionProfileAssessment.new(evidence:,
          trace_id: (span.context.hex_trace_id if span.context.valid?), tracer: @tracer, trace_tags: TRACE_TAGS)
        assessment.call(synthesizer: @synthesizer)
        revision = record_and_apply(current:, expression_texts:, assessment:)
        span.set_attribute("expression_profile_id", revision.expression_profile_id)
        span.set_attribute("expression_profile_revision_id", revision.id)
        span.set_attribute("expression_profile_eval_id", revision.expression_profile_eval_id)
        revision
      rescue StandardError
        span.status = OpenTelemetry::Trace::Status.error("Expression profile refresh failed")
        span.set_attribute("langfuse.observation.level", "ERROR")
        raise
      end
    ensure
      @tracer_provider&.force_flush(timeout: 5)
    end

    private

    def with_owner_lock
      ExpressionProfile.transaction(requires_new: true) do
        user = Identity::User.lock.find_by(id: @user_id)
        raise IdentityUnavailable unless user&.active?

        yield user
      end
    end

    def capture_evidence
      RatingExpression.joins(rating: { rating_film: :film }).merge(Rating.current)
        .where(rating_films: { user_id: @user_id }).order(:id)
        .pluck("rating_expressions.id", "ratings.id", "films.id", "films.title", "films.release_date", "rating_expressions.text")
        .map do |expression_id, rating_id, film_id, title, release_date, text|
          { "expression_id" => expression_id, "rating_id" => rating_id, "film_id" => film_id,
            "film_title" => title, "film_release_date" => release_date&.iso8601, "text" => text }
        end
    end

    def texts_by_film(evidence)
      evidence.group_by { |expression| expression.fetch("film_id") }.transform_values { |expressions| expressions.pluck("text") }
    end

    def record_and_apply(current:, expression_texts:, assessment:)
      with_owner_lock do |user|
        expression_profile = ExpressionProfile.find_by(user:)
        unless expression_profile&.current_revision&.id == current&.id && texts_by_film(capture_evidence) == expression_texts
          raise ExpressionProfileRefreshFailed.new(reason: :stale_inputs)
        end

        expression_profile ||= ExpressionProfile.create!(user:)
        evaluation = ExpressionProfileEval.record!(expression_profile:, assessment:)
        evaluation.apply_profile!
      end
    end
  end
end
