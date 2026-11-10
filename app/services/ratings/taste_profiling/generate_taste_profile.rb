module Ratings
  module TasteProfiling
    class GenerateTasteProfile
      CONFIGURATION = JSON.parse(Rails.root.join("config/taste_profile_synthesis.json").read).freeze
      INSTRUCTIONS = File.read(File.join(__dir__, "taste_profile_prompt.txt")).freeze

      SCHEMA = {
        type: "object", additionalProperties: false, required: %w[profile conclusions],
        properties: {
          profile: { type: "string" },
          conclusions: {
            type: "array", items: {
              type: "object", additionalProperties: false, required: %w[anchor claim explanation citations],
              properties: {
                anchor: { type: "string" },
                claim: { type: "string" },
                explanation: { type: "string" },
                citations: {
                  type: "array", items: {
                    type: "object", additionalProperties: false, required: %w[rating_id quote],
                    properties: { rating_id: { type: "integer" }, quote: { type: "string" } }
                  }
                }
              }
            }
          }
        }
      }.freeze

      MAXIMUM_PROFILE_LENGTH = 6_000

      attr_reader :input, :result

      def initialize(evidence:, basis:, trace_id:, tracer:, trace_tags:)
        @evidence, @trace_id, @tracer, @trace_tags = evidence, trace_id, tracer, trace_tags
        @notes_by_rating = evidence.index_by { |note| note.fetch("rating_id") }
        @basis = basis
        @input = []
        @changes = NoteComparison.new(previous: basis&.fetch(:evidence) || [], current: evidence)
        @prior_claims = basis.present? ? prior_claims : []
        @note_changes = @changes.changes.map { |before, after| note_change(before, after) }
        if citable_rating_ids.empty?
          @note_changes += @changes.retained.values.map { |note| note_change(note, note) }
        end
      end

      def call(client:)
        profile, annotations, synthesis = @evidence.empty? ? [ "", [], nil ] : synthesize(client)
        @result = { "evidence" => @evidence, "profile" => profile,
          "annotations" => annotations, "synthesis" => synthesis, "trace_id" => @trace_id,
          "provider_response" => @provider_response }
        self
      end

      private

      def synthesis_input
        previous_profile = { "narrative" => @basis.fetch(:profile), "claims" => @prior_claims } if @basis.present?
        { "previous_profile" => previous_profile, "note_changes" => @note_changes }
      end

      def prior_claims
        evidence = @basis.fetch(:evidence).index_by { |note| note.fetch("rating_id") }
        @basis.fetch(:annotations).map do |annotation|
          supporting_notes = annotation.fetch("citations").group_by { |citation| citation.fetch("rating_id") }.map do |id, citations|
            prior_support(evidence.fetch(id), citations)
          end
          annotation.slice("claim", "explanation").merge("supporting_notes" => supporting_notes)
        end
      end

      def prior_support(previous, citations)
        id = previous.fetch("rating_id")
        current = @changes.current_by_film[previous.fetch("film_id")]
        quotes = citations.map do |citation|
          previous.fetch("text")[citation.fetch("start_offset")...citation.fetch("end_offset")]
        end
        support = {
          "film_title" => previous.fetch("film_title"), "previous_rating_id" => id,
          "current_rating_id" => current&.fetch("rating_id"), "quotes" => quotes,
          "retained_quotes" => quotes.select { |quote| current && unique_quote_start(current.fetch("text"), quote) }
        }
        support["text"] = previous.fetch("text") if @changes.retained.key?(id)
        support
      end

      def note_change(before, after)
        film = after || before
        change = {
          "film_id" => film.fetch("film_id"), "film_title" => film.fetch("film_title"),
          "source_paragraphs" => film.fetch("source_paragraphs", []),
          "before" => before&.fetch("text"), "after" => after&.fetch("text"),
          "before_rating_id" => before&.fetch("rating_id"), "after_rating_id" => after&.fetch("rating_id")
        }
        if before && after && before["source_paragraphs"] != after["source_paragraphs"]
          change["before_source_paragraphs"] = before.fetch("source_paragraphs", [])
        end
        change
      end

      def synthesis_basis
        {
          "previous_profile_revision_id" => @basis.fetch(:revision_id),
          "note_changes" => @note_changes.map { |change| change.slice("before_rating_id", "after_rating_id") },
          "retained_rating_ids" => @changes.retained.transform_values { |note| note.fetch("rating_id") }
        }
      end

      def citable_rating_ids
        prior_ids = @prior_claims.flat_map { |claim| claim.fetch("supporting_notes").pluck("current_rating_id") }
        (@note_changes.pluck("after_rating_id") + prior_ids).compact.to_set
      end

      def synthesize(client)
        @tracer.in_span("synthesize-taste-profile", attributes: {
          "langfuse.observation.type" => "generation",
          "langfuse.trace.tags" => @trace_tags,
          "langfuse.environment" => Rails.env.to_s
        }, record_exception: false) do |span|
          profile, annotations, synthesis = validated_synthesis(request_synthesis(client))
          span.set_attribute("langfuse.observation.model.name", synthesis.fetch("model"))
          span.set_attribute("langfuse.observation.usage_details", synthesis.fetch("usage").to_json)
          [ profile, annotations, synthesis ]
        rescue Errors::TasteProfileRefreshFailed
          span.status = OpenTelemetry::Trace::Status.error("Taste profile synthesis failed")
          span.set_attribute("langfuse.observation.level", "ERROR")
          raise
        end
      end

      def request_synthesis(client)
        request = openai_request
        response = request_completion(client, request)
        invalid_response unless response.status.to_s == "completed"

        parts = response.output.select { |item| item.type.to_s == "message" }.flat_map(&:content)
        invalid_response unless parts.all? { |part| part.type.to_s == "output_text" }

        result = JSON.parse(parts.map(&:text).join("\n"))
        invalid_response unless result.is_a?(Hash)

        @input << { "phase" => "synthesize-taste-profile", "request" => request }
        @provider_response = result
        result.slice("profile", "conclusions").merge(
          "provider" => "openai", "model" => response.model,
          "usage" => { "input" => response.usage&.input_tokens, "output" => response.usage&.output_tokens },
          "settings" => CONFIGURATION.except("model").merge("requested_model" => CONFIGURATION.fetch("model")))
      rescue JSON::ParserError
        invalid_response
      end

      def openai_request
        input = JSON.generate(synthesis_input)
        if input.bytesize + INSTRUCTIONS.bytesize + JSON.generate(SCHEMA).bytesize > CONFIGURATION.fetch("maximum_request_bytes")
          raise Errors::TasteProfileRefreshFailed.new(reason: :input_limit)
        end

        { model: CONFIGURATION.fetch("model"), instructions: INSTRUCTIONS, input:,
          reasoning: { effort: CONFIGURATION.fetch("effort") }, max_output_tokens: CONFIGURATION.fetch("max_output_tokens"),
          store: false, truncation: :disabled, text: { format: { type: "json_schema", name: "taste_profile", schema: SCHEMA, strict: true } } }
      end

      def request_completion(client, request)
        raise Errors::TasteProfileRefreshFailed.new(reason: :provider_failure) unless client.present?

        client.responses.create(**request)
      rescue StandardError
        raise Errors::TasteProfileRefreshFailed.new(reason: :provider_failure), cause: nil
      end

      def validated_synthesis(result)
        raise Errors::TasteProfileRefreshFailed.new(reason: :invalid_response) unless result.is_a?(Hash)

        profile, conclusions, provider, model, usage = result.values_at("profile", "conclusions", "provider", "model", "usage")
        unless [ provider, model ].all? { |text| text.is_a?(String) && text.present? } &&
            usage.is_a?(Hash) && usage.values_at("input", "output").all? { |count| count.is_a?(Integer) && count >= 0 }
          raise Errors::TasteProfileRefreshFailed.new(reason: :invalid_response)
        end

        invalid_response unless profile.is_a?(String) && profile.present? && profile.length <= MAXIMUM_PROFILE_LENGTH

        annotations = validated_conclusions(profile, conclusions)
        provenance = result.slice("settings").merge(
          "prompt" => { "instructions" => INSTRUCTIONS, "sha256" => Digest::SHA256.hexdigest(INSTRUCTIONS), "schema" => SCHEMA })
        provenance["basis"] = synthesis_basis if @basis.present?
        [ profile, annotations, provenance.merge("provider" => provider, "model" => model, "usage" => usage.slice("input", "output")) ]
      end

      def validated_conclusions(profile, conclusions)
        invalid_response unless conclusions.is_a?(Array) && conclusions.any?

        evidence_ids = citable_rating_ids
        previous_end = 0
        conclusions.map do |conclusion|
          invalid_response unless conclusion.is_a?(Hash)
          anchor, claim, explanation, citations = conclusion.values_at("anchor", "claim", "explanation", "citations")
          unless [ anchor, claim, explanation ].all? { |text| text.is_a?(String) && text.present? } &&
              citations.is_a?(Array) && citations.any?
            invalid_response
          end

          start = profile.index(anchor)
          invalid_response unless start && start >= previous_end && profile.index(anchor, start + 1).nil?

          previous_end = start + anchor.length
          { "claim" => claim.strip, "end_offset" => previous_end, "explanation" => explanation.strip,
            "citations" => citations.map { |citation| validated_citation(citation, evidence_ids) }.uniq }
        end
      end

      def validated_citation(citation, evidence_ids)
        invalid_response unless citation.is_a?(Hash)

        rating_id, quote = citation.values_at("rating_id", "quote")
        invalid_response unless rating_id.is_a?(Integer) && evidence_ids.include?(rating_id) &&
          quote.is_a?(String) && quote.present?

        text = @notes_by_rating.fetch(rating_id).fetch("text")
        start = unique_quote_start(text, quote)
        invalid_response unless start

        { "rating_id" => rating_id, "start_offset" => start, "end_offset" => start + quote.length }
      end

      def unique_quote_start(text, quote)
        start = text.index(quote)
        start if start && text.index(quote, start + 1).nil?
      end

      def invalid_response
        raise Errors::TasteProfileRefreshFailed.new(reason: :invalid_response)
      end
    end
  end
end
