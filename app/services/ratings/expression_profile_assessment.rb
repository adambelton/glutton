module Ratings
  class ExpressionProfileAssessment
    attr_reader :result

    def initialize(evidence:, trace_id:, tracer:, trace_tags:)
      @evidence, @trace_id, @tracer, @trace_tags = evidence, trace_id, tracer, trace_tags
    end

    def call(synthesizer:)
      profile, synthesis = @evidence.empty? ? [ "", nil ] : synthesize(synthesizer)
      @result = { "evidence" => @evidence, "profile" => profile, "synthesis" => synthesis, "trace_id" => @trace_id }
      self
    end

    private

    def synthesize(synthesizer)
      @tracer.in_span("synthesize-expression-profile", attributes: {
        "langfuse.observation.type" => "generation",
        "langfuse.trace.tags" => @trace_tags,
        "langfuse.environment" => Rails.env.to_s
      }, record_exception: false) do |span|
        expressions = @evidence.map { |expression| expression.slice("film_title", "film_release_date", "text") }
        profile, synthesis = validated_synthesis(request_synthesis(synthesizer, expressions))
        span.set_attribute("langfuse.observation.model.name", synthesis.fetch("model"))
        span.set_attribute("langfuse.observation.usage_details", synthesis.fetch("usage").to_json)
        [ profile, synthesis ]
      rescue ExpressionProfileRefreshFailed
        span.status = OpenTelemetry::Trace::Status.error("Expression profile synthesis failed")
        span.set_attribute("langfuse.observation.level", "ERROR")
        raise
      end
    end

    def request_synthesis(synthesizer, expressions)
      synthesizer.call(expressions:)
    rescue StandardError
      raise ExpressionProfileRefreshFailed.new(reason: :provider_failure), cause: nil
    end

    def validated_synthesis(result)
      raise ExpressionProfileRefreshFailed.new(reason: :invalid_response) unless result.is_a?(Hash)

      profile, provider, model, usage = result.values_at("profile", "provider", "model", "usage")
      profile = profile.strip if profile.is_a?(String)
      unless [ profile, provider, model ].all? { |text| text.is_a?(String) && text.present? } &&
          usage.is_a?(Hash) && usage.values_at("input", "output").all? { |count| count.is_a?(Integer) && count >= 0 }
        raise ExpressionProfileRefreshFailed.new(reason: :invalid_response)
      end

      [ profile, { "provider" => provider, "model" => model, "usage" => usage.slice("input", "output") } ]
    end
  end
end
