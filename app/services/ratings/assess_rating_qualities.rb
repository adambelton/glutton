module Ratings
  class AssessRatingQualities
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
      existing = rating.rating_quality_evals.order(id: :desc).first
      return existing if existing.present?

      qualities = rating_film.film.qualities.order(:id).to_h do |quality|
        [ quality.id.to_s, { "name" => quality.name, "match_rule" => quality.match_rule, "not_sufficient" => quality.not_sufficient } ]
      end
      return if qualities.empty?

      expressions = rating.rating_expressions.pluck(:id, :text).to_h.transform_keys(&:to_s)
      tags = [ "ratings", "explicit-assessment" ]
      @tracer.in_span("assess-rating-qualities", attributes: {
        "langfuse.trace.name" => "assess-rating-qualities",
        "langfuse.observation.type" => "span",
        "langfuse.trace.tags" => tags,
        "langfuse.environment" => Rails.env.to_s,
        "langfuse.observation.input" => { rating_id: rating.id, expression_count: expressions.size, quality_count: qualities.size }.to_json
      }, record_exception: false) do |span|
        assessment = ExplicitQualityAssessment.new(expressions:, qualities:,
          trace_id: (span.context.hex_trace_id if span.context.valid?))
        TypeSafeClient.with_trace_tags(tags) { assessment.call(client: @client) }
        evaluation = record_and_apply(rating_film, rating, assessment)
        span.set_attribute("rating_quality_eval_id", evaluation.id)
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

    def record_and_apply(rating_film, rating, assessment)
      rating_film.with_lock(requires_new: true) do
        ensure_current!(rating_film, rating)
        existing = rating.rating_quality_evals.order(id: :desc).first
        next existing if existing.present?

        evaluation = RatingQualityEval.record!(rating:, assessment:)
        evaluation.apply_quality_scores!
        evaluation
      end
    end

    def ensure_current!(rating_film, rating)
      raise QualityAssessmentFailed.new(reason: :stale_rating) unless rating_film.ratings.maximum(:id) == rating.id
    end
  end
end
