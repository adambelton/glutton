module Ratings
  class AssessRatingQualities
    TRACE_NAME = "assess-rating-qualities".freeze
    TRACE_TAGS = [ "ratings", "quality-assessment" ].freeze

    def self.call(rating_id:, client: nil, tracer_provider: Rails.application.config.x.langfuse_tracer_provider)
      new(rating_id:, client:, tracer_provider:).call
    end

    def initialize(rating_id:, client:, tracer_provider:)
      @rating_id = rating_id
      @tracer_provider = tracer_provider
      @tracer = (tracer_provider || OpenTelemetry::Trace::TracerProvider.new).tracer("glutton.ratings", "1")
      @client = client || TypeSafeClient.new(tracer: @tracer, profile: :ratings)
    end

    def call
      rating = Rating.find(@rating_id)
      rating_film = rating.rating_film
      ensure_current!(rating_film, rating)
      profile_revision = ExpressionProfile.find_by(user_id: rating_film.user_id)&.current_revision
      return unless rating.can_assess_qualities_for?(profile_revision&.id)

      explicit_evidence = rating.quality_evidence_for_reassessment
      qualities = explicit_evidence&.fetch("qualities") || capture_qualities(rating_film)
      return if qualities.empty?

      expressions = rating.rating_expressions.pluck(:id, :text).to_h.transform_keys(&:to_s)
      @tracer.in_span(TRACE_NAME, attributes: {
        "langfuse.trace.name" => TRACE_NAME,
        "langfuse.observation.type" => "span",
        "langfuse.trace.tags" => TRACE_TAGS,
        "langfuse.environment" => Rails.env.to_s,
        "langfuse.observation.input" => { rating_id: rating.id, expression_count: expressions.size, quality_count: qualities.size }.to_json
      }, record_exception: false) do |span|
        trace_id = span.context.hex_trace_id if span.context.valid?
        evaluation = TypeSafeClient.with_trace_tags(TRACE_TAGS) do
          assess_and_record(rating:, expressions:, qualities:, profile_revision:, trace_id:, explicit_evidence:)
        end
        span.set_attribute("rating_quality_eval_id", evaluation.id) if evaluation.present?
        evaluation
      rescue StandardError
        span.status = OpenTelemetry::Trace::Status.error("Rating quality assessment failed")
        span.set_attribute("langfuse.observation.level", "ERROR")
        raise
      end
    ensure
      @tracer_provider&.force_flush(timeout: 5)
    end

    private

    def capture_qualities(rating_film)
      rating_film.film.qualities.order(:id).to_h do |quality|
        [ quality.id.to_s, { "name" => quality.name, "match_rule" => quality.match_rule, "not_sufficient" => quality.not_sufficient } ]
      end
    end

    def assess_and_record(rating:, expressions:, qualities:, profile_revision:, trace_id:, explicit_evidence:)
      assessment = RatingQualityAssessment.new(expressions:, qualities:, profile_revision_id: profile_revision&.id,
        profile: profile_revision&.profile, trace_id:, explicit_evidence:).call(client: @client)
      record_and_apply(rating:, assessment:)
    rescue QualityAssessmentFailed => error
      raise unless error.reason == :explicit_evidence_changed
      return unless rating.can_assess_qualities_for?(profile_revision.id)

      explicit_evidence = rating.quality_evidence_for_reassessment
      assessment = RatingQualityAssessment.new(expressions:, qualities:, profile_revision_id: profile_revision.id,
        profile: profile_revision.profile, trace_id:, explicit_evidence:, previous_assessment: assessment).call(client: @client)
      record_and_apply(rating:, assessment:)
    end

    def record_and_apply(rating:, assessment:)
      Rating.transaction(requires_new: true) do
        evaluation = RatingQualityEval.record!(rating:, assessment:)
        raise ActiveRecord::Rollback unless rating.apply_quality_evaluation!(evaluation:)

        evaluation
      end
    end

    def ensure_current!(rating_film, rating)
      raise QualityAssessmentFailed.new(reason: :stale_rating) unless rating_film.ratings.maximum(:id) == rating.id
    end
  end
end
