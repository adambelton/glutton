module Ratings
  class ExpressionProfileSynthesizer
    CONFIGURATION = JSON.parse(Rails.root.join("config/expression_profile_synthesis.json").read).freeze

    def initialize(openai_client: Rails.application.config.x.openai_client)
      @openai_client = openai_client
    end

    def call(input:, instructions:, schema:)
      input = JSON.generate(input)
      fail_synthesis(:input_limit) if input.bytesize + instructions.bytesize + JSON.generate(schema).bytesize > CONFIGURATION.fetch("maximum_request_bytes")

      request = { model: CONFIGURATION.fetch("model"), instructions:, input:,
        reasoning: { effort: CONFIGURATION.fetch("effort") }, max_output_tokens: CONFIGURATION.fetch("max_output_tokens"), store: false,
        truncation: :disabled, text: { format: { type: "json_schema", name: "expression_profile", schema:, strict: true } } }
      text, model, usage = openai_profile(request)
      result = JSON.parse(text)
      fail_synthesis(:invalid_response) unless result.is_a?(Hash)

      { "profile" => result["profile"], "conclusions" => result["conclusions"], "provider" => "openai", "model" => model, "usage" => usage,
        "request" => request, "response" => result, "settings" => CONFIGURATION.except("model").merge("requested_model" => CONFIGURATION.fetch("model")) }
    rescue JSON::ParserError
      fail_synthesis(:invalid_response)
    end

    private

    def openai_profile(request)
      fail_synthesis(:provider_failure) unless @openai_client

      format = request.fetch(:text).fetch(:format)
      response = @openai_client.responses.create(**request.merge(text: { format_: format }))
      fail_synthesis(:invalid_response) unless response.status.to_s == "completed"

      parts = response.output.select { |item| item.type.to_s == "message" }.flat_map(&:content)
      fail_synthesis(:invalid_response) unless parts.all? { |part| part.type.to_s == "output_text" }

      [ parts.map(&:text).join("\n"), response.model,
        { "input" => response.usage&.input_tokens, "output" => response.usage&.output_tokens } ]
    end

    def fail_synthesis(reason)
      raise ExpressionProfileRefreshFailed.new(reason:), cause: nil
    end
  end
end
