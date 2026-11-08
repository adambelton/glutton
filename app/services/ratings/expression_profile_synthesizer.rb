module Ratings
  class ExpressionProfileSynthesizer
    MAXIMUM_INPUT_BYTES = 48_000
    MAXIMUM_OUTPUT_TOKENS = 3_200

    def initialize(model:, effort:, openai_client: Rails.application.config.x.openai_client)
      @model, @effort, @openai_client = model, effort, openai_client
    end

    def call(expressions:, instructions:, schema:)
      input = JSON.generate(expressions)
      fail_synthesis(:input_limit) if input.bytesize + instructions.bytesize + JSON.generate(schema).bytesize > MAXIMUM_INPUT_BYTES

      text, model, usage = openai_profile(input, instructions, schema)
      result = JSON.parse(text)
      fail_synthesis(:invalid_response) unless result.is_a?(Hash)

      { "paragraphs" => result["paragraphs"], "provider" => "openai", "model" => model, "usage" => usage,
        "settings" => { "requested_model" => @model, "effort" => @effort, "max_output_tokens" => MAXIMUM_OUTPUT_TOKENS } }
    rescue JSON::ParserError
      fail_synthesis(:invalid_response)
    end

    private

    def openai_profile(input, instructions, schema)
      fail_synthesis(:provider_failure) unless @openai_client

      response = @openai_client.responses.create(model: @model, instructions:, input:,
        reasoning: { effort: @effort }, max_output_tokens: MAXIMUM_OUTPUT_TOKENS, store: false,
        truncation: :disabled, text: { format_: { type: "json_schema", name: "expression_profile", schema:, strict: true } })
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
