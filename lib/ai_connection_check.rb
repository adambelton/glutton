require "json"

# An explicit operational check, not the film-analysis generation workflow.
class AiConnectionCheck
  TRACE_NAME = "check-ai-connection".freeze
  TRACE_TAGS = [ "connection-check" ].freeze

  INSTRUCTIONS = "Reply with exactly OK.".freeze
  INPUT = "Verify this API connection.".freeze

  def initialize(client:, provider:, environment:)
    @client = client
    @provider = provider
    @environment = environment
  end

  def call(model:)
    raise ArgumentError, "OpenAI and Langfuse must both be configured" unless @client && @provider
    raise ArgumentError, "Set OPENAI_MODEL explicitly for this check" if model.to_s.strip.empty?

    result = nil
    ActivityMonitoring.trace_ai_workflow(TRACE_NAME, scope: ActivityMonitoring::Scopes::CONNECTION_CHECK, provider: @provider, tags: TRACE_TAGS, environment: @environment, version: "1",
      input: { purpose: "Verify OpenAI and Langfuse connectivity", model: model }) do |root, tracer|
      ActivityMonitoring.trace_ai_generation("check-openai-response", tracer:, tags: TRACE_TAGS, trace_name: TRACE_NAME,
        environment: @environment, version: "1", model:, parameters: { max_output_tokens: 32, store: false },
        input: { instructions: INSTRUCTIONS, input: INPUT }) do |generation|
        response = @client.responses.create(
          model: model, instructions: INSTRUCTIONS, input: INPUT, max_output_tokens: 32, store: false
        )
        generation.set_model(response.model)
        generation.set_output(response.output_text)
        generation.set_response(id: response.id, status: response.status)
        if response.usage
          generation.set_usage(
            input: response.usage.input_tokens, output: response.usage.output_tokens,
            total: response.usage.total_tokens
          )
        end
        raise "OpenAI connection check did not complete successfully" unless response.status.to_s == "completed" && response.output_text.strip == "OK"

        result = { trace_id: root.trace_id, response_id: response.id, model: response.model, output: response.output_text }
        root.set_output(status: "passed", response_id: response.id)
      end
    end
    result
  end
end
