module Ratings
  class ExpressionProfileAssessment
    INSTRUCTIONS = File.read(File.join(__dir__, "expression_profile_prompt.txt")).freeze

    SCHEMA = {
      type: "object", additionalProperties: false, required: %w[paragraphs],
      properties: {
        paragraphs: {
          type: "array", items: {
            type: "object", additionalProperties: false, required: %w[text explanation expression_ids],
            properties: {
              text: { type: "string" },
              explanation: { type: "string" },
              expression_ids: { type: "array", items: { type: "integer" } }
            }
          }
        }
      }
    }.freeze

    MAXIMUM_PROFILE_LENGTH = 6_000

    attr_reader :result

    def initialize(evidence:, trace_id:, tracer:, trace_tags:)
      @evidence, @trace_id, @tracer, @trace_tags = evidence, trace_id, tracer, trace_tags
    end

    def call(synthesizer:)
      paragraphs, synthesis = @evidence.empty? ? [ [], nil ] : synthesize(synthesizer)
      @result = { "evidence" => @evidence, "profile" => paragraphs.pluck("text").join("\n\n"),
        "annotations" => paragraphs, "synthesis" => synthesis, "trace_id" => @trace_id }
      self
    end

    private

    def synthesis_input
      @evidence.group_by { |expression| expression.fetch("film_id") }.values.map do |film_expressions|
        film = film_expressions.first
        { "film_title" => film.fetch("film_title"), "source_paragraphs" => film.fetch("source_paragraphs"),
          "expressions" => film_expressions.map { |expression| expression.slice("expression_id", "text") } }
      end
    end

    def synthesize(synthesizer)
      @tracer.in_span("synthesize-expression-profile", attributes: {
        "langfuse.observation.type" => "generation",
        "langfuse.trace.tags" => @trace_tags,
        "langfuse.environment" => Rails.env.to_s
      }, record_exception: false) do |span|
        paragraphs, synthesis = validated_synthesis(request_synthesis(synthesizer))
        span.set_attribute("langfuse.observation.model.name", synthesis.fetch("model"))
        span.set_attribute("langfuse.observation.usage_details", synthesis.fetch("usage").to_json)
        [ paragraphs, synthesis ]
      rescue ExpressionProfileRefreshFailed
        span.status = OpenTelemetry::Trace::Status.error("Expression profile synthesis failed")
        span.set_attribute("langfuse.observation.level", "ERROR")
        raise
      end
    end

    def request_synthesis(synthesizer)
      synthesizer.call(expressions: synthesis_input, instructions: INSTRUCTIONS, schema: SCHEMA)
    rescue ExpressionProfileRefreshFailed
      raise
    rescue StandardError
      raise ExpressionProfileRefreshFailed.new(reason: :provider_failure), cause: nil
    end

    def validated_synthesis(result)
      raise ExpressionProfileRefreshFailed.new(reason: :invalid_response) unless result.is_a?(Hash)

      paragraphs, provider, model, usage = result.values_at("paragraphs", "provider", "model", "usage")
      unless [ provider, model ].all? { |text| text.is_a?(String) && text.present? } &&
          usage.is_a?(Hash) && usage.values_at("input", "output").all? { |count| count.is_a?(Integer) && count >= 0 }
        raise ExpressionProfileRefreshFailed.new(reason: :invalid_response)
      end

      paragraphs = validated_paragraphs(paragraphs)
      provenance = result.slice("settings").merge(
        "prompt" => { "instructions" => INSTRUCTIONS, "sha256" => Digest::SHA256.hexdigest(INSTRUCTIONS), "schema" => SCHEMA })
      [ paragraphs, provenance.merge("provider" => provider, "model" => model, "usage" => usage.slice("input", "output")) ]
    end

    def validated_paragraphs(paragraphs)
      invalid_response unless paragraphs.is_a?(Array) && paragraphs.any?

      evidence_ids = @evidence.pluck("expression_id").to_set
      paragraphs = paragraphs.map do |paragraph|
        invalid_response unless paragraph.is_a?(Hash)
        content, explanation, ids = paragraph.values_at("text", "explanation", "expression_ids")
        unless [ content, explanation ].all? { |text| text.is_a?(String) && text.present? } &&
            ids.is_a?(Array) && ids.any? && ids.all? { |id| id.is_a?(Integer) && evidence_ids.include?(id) }
          invalid_response
        end

        { "text" => content.strip, "explanation" => explanation.strip, "expression_ids" => ids.uniq }
      end
      invalid_response if paragraphs.pluck("text").join("\n\n").length > MAXIMUM_PROFILE_LENGTH

      paragraphs
    end

    def invalid_response
      raise ExpressionProfileRefreshFailed.new(reason: :invalid_response)
    end
  end
end
