module Ratings
  class ExpressionProfileAssessment
    INSTRUCTIONS = File.read(File.join(__dir__, "expression_profile_prompt.txt")).freeze

    SCHEMA = {
      type: "object", additionalProperties: false, required: %w[profile conclusions],
      properties: {
        profile: { type: "string" },
        conclusions: {
          type: "array", items: {
            type: "object", additionalProperties: false, required: %w[anchor claim explanation expression_ids],
            properties: {
              anchor: { type: "string" },
              claim: { type: "string" },
              explanation: { type: "string" },
              expression_ids: { type: "array", items: { type: "integer" } }
            }
          }
        }
      }
    }.freeze

    MAXIMUM_PROFILE_LENGTH = 6_000

    attr_reader :input, :result

    def initialize(evidence:, basis:, trace_id:, tracer:, trace_tags:)
      @evidence, @trace_id, @tracer, @trace_tags = evidence, trace_id, tracer, trace_tags
      @basis = basis
      @input = []
      if basis.present?
        @changes = ExpressionProfileEvidenceChanges.new(previous: basis.fetch(:evidence), current: evidence)
        @prior_claims = prior_claims
        @changes = nil if citable_expression_ids.empty?
      end
    end

    def call(synthesizer:)
      profile, annotations, synthesis = @evidence.empty? ? [ "", [], nil ] : synthesize(synthesizer)
      @result = { "evidence" => @evidence, "profile" => profile,
        "annotations" => annotations, "synthesis" => synthesis, "trace_id" => @trace_id,
        "provider_response" => @provider_response }
      self
    end

    private

    def synthesis_input
      return by_film(@evidence) unless @changes.present?

      {
        "previous_profile" => { "narrative" => @basis.fetch(:profile), "claims" => @prior_claims },
        "added" => by_film(@changes.added),
        "removed" => by_film(@changes.removed)
      }
    end

    def prior_claims
      evidence = @basis.fetch(:evidence).index_by { |expression| expression.fetch("expression_id") }
      @basis.fetch(:annotations).map do |annotation|
        supporting_expressions = annotation.fetch("expression_ids").map do |id|
          previous = evidence.fetch(id)
          previous.slice("film_title", "text").merge(
            "previous_expression_id" => id, "current_expression_id" => @changes.retained[id]&.fetch("expression_id"))
        end
        annotation.slice("claim", "explanation").merge("supporting_expressions" => supporting_expressions)
      end
    end

    def by_film(evidence)
      evidence.group_by { |expression| expression.fetch("film_id") }.values.map do |film_expressions|
        film = film_expressions.first
        { "film_title" => film.fetch("film_title"), "source_paragraphs" => film.fetch("source_paragraphs", []),
          "expressions" => film_expressions.map { |expression| expression.slice("expression_id", "text") } }
      end
    end

    def synthesis_basis
      {
        "previous_profile_revision_id" => @basis.fetch(:revision_id),
        "added_expression_ids" => @changes.added.pluck("expression_id"),
        "removed_expression_ids" => @changes.removed.pluck("expression_id"),
        "retained_expression_ids" => @changes.retained.transform_values { |expression| expression.fetch("expression_id") }
      }
    end

    def citable_expression_ids
      return @evidence.pluck("expression_id").to_set unless @changes.present?

      retained = @prior_claims.flat_map { |claim| claim.fetch("supporting_expressions").pluck("current_expression_id") }.compact
      (retained + @changes.added.pluck("expression_id")).to_set
    end

    def synthesize(synthesizer)
      @tracer.in_span("synthesize-expression-profile", attributes: {
        "langfuse.observation.type" => "generation",
        "langfuse.trace.tags" => @trace_tags,
        "langfuse.environment" => Rails.env.to_s
      }, record_exception: false) do |span|
        profile, annotations, synthesis = validated_synthesis(request_synthesis(synthesizer))
        span.set_attribute("langfuse.observation.model.name", synthesis.fetch("model"))
        span.set_attribute("langfuse.observation.usage_details", synthesis.fetch("usage").to_json)
        [ profile, annotations, synthesis ]
      rescue ExpressionProfileRefreshFailed
        span.status = OpenTelemetry::Trace::Status.error("Expression profile synthesis failed")
        span.set_attribute("langfuse.observation.level", "ERROR")
        raise
      end
    end

    def request_synthesis(synthesizer)
      payload = synthesis_input
      response = synthesizer.call(input: payload, instructions: INSTRUCTIONS, schema: SCHEMA)
      if response.is_a?(Hash)
        @input << { "phase" => "synthesize-expression-profile", "request" =>
          response.fetch("request") { { "input" => payload, "instructions" => INSTRUCTIONS, "schema" => SCHEMA } } }
        @provider_response = response.fetch("response") { response.slice("profile", "conclusions") }
      end
      response
    rescue ExpressionProfileRefreshFailed
      raise
    rescue StandardError
      raise ExpressionProfileRefreshFailed.new(reason: :provider_failure), cause: nil
    end

    def validated_synthesis(result)
      raise ExpressionProfileRefreshFailed.new(reason: :invalid_response) unless result.is_a?(Hash)

      profile, conclusions, provider, model, usage = result.values_at("profile", "conclusions", "provider", "model", "usage")
      unless [ provider, model ].all? { |text| text.is_a?(String) && text.present? } &&
          usage.is_a?(Hash) && usage.values_at("input", "output").all? { |count| count.is_a?(Integer) && count >= 0 }
        raise ExpressionProfileRefreshFailed.new(reason: :invalid_response)
      end

      invalid_response unless profile.is_a?(String) && profile.present? && profile.length <= MAXIMUM_PROFILE_LENGTH

      annotations = validated_conclusions(profile, conclusions)
      provenance = result.slice("settings").merge(
        "prompt" => { "instructions" => INSTRUCTIONS, "sha256" => Digest::SHA256.hexdigest(INSTRUCTIONS), "schema" => SCHEMA })
      provenance["basis"] = synthesis_basis if @changes.present?
      [ profile, annotations, provenance.merge("provider" => provider, "model" => model, "usage" => usage.slice("input", "output")) ]
    end

    def validated_conclusions(profile, conclusions)
      invalid_response unless conclusions.is_a?(Array) && conclusions.any?

      evidence_ids = citable_expression_ids
      previous_end = 0
      conclusions.map do |conclusion|
        invalid_response unless conclusion.is_a?(Hash)
        anchor, claim, explanation, ids = conclusion.values_at("anchor", "claim", "explanation", "expression_ids")
        unless [ anchor, claim, explanation ].all? { |text| text.is_a?(String) && text.present? } &&
            ids.is_a?(Array) && ids.any? && ids.all? { |id| id.is_a?(Integer) && evidence_ids.include?(id) }
          invalid_response
        end

        start = profile.index(anchor)
        invalid_response unless start && start >= previous_end && profile.index(anchor, start + 1).nil?

        previous_end = start + anchor.length
        { "claim" => claim.strip, "end_offset" => previous_end, "explanation" => explanation.strip, "expression_ids" => ids.uniq }
      end
    end

    def invalid_response
      raise ExpressionProfileRefreshFailed.new(reason: :invalid_response)
    end
  end
end
