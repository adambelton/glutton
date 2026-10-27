require "json"

# An explicit operational check, not the film-analysis generation workflow.
class AiConnectionCheck
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

    tracer = @provider.tracer("glutton.ai.connection-check", "1")
    common = {
      "langfuse.trace.name" => "check-ai-connection",
      "langfuse.environment" => @environment,
      "langfuse.trace.tags" => [ "connection-check" ],
      "langfuse.version" => "1"
    }
    result = nil
    tracer.in_span("check-ai-connection", attributes: common.merge(
      "langfuse.observation.type" => "span",
      "langfuse.observation.input" => { purpose: "Verify OpenAI and Langfuse connectivity", model: model }.to_json
    ), record_exception: false) do |root|
      tracer.in_span("check-openai-response", attributes: common.merge(
        "langfuse.observation.type" => "generation",
        "langfuse.observation.model.name" => model,
        "langfuse.observation.model.parameters" => { max_output_tokens: 32, store: false }.to_json,
        "langfuse.observation.input" => { instructions: INSTRUCTIONS, input: INPUT }.to_json
      ), record_exception: false) do |generation|
        response = @client.responses.create(
          model: model, instructions: INSTRUCTIONS, input: INPUT, max_output_tokens: 32, store: false
        )
        generation.set_attribute("langfuse.observation.model.name", response.model)
        generation.set_attribute("langfuse.observation.output", response.output_text.to_json)
        generation.set_attribute("langfuse.observation.metadata.response_id", response.id)
        generation.set_attribute("langfuse.observation.metadata.response_status", response.status.to_s)
        if response.usage
          generation.set_attribute("langfuse.observation.usage_details", {
            input: response.usage.input_tokens, output: response.usage.output_tokens,
            total: response.usage.total_tokens
          }.to_json)
        end
        raise "OpenAI connection check did not complete successfully" unless response.status.to_s == "completed" && response.output_text.strip == "OK"

        result = { trace_id: root.context.hex_trace_id, response_id: response.id, model: response.model, output: response.output_text }
        root.set_attribute("langfuse.observation.output", { status: "passed", response_id: response.id }.to_json)
      end
    end
    result
  ensure
    @provider&.force_flush(timeout: 5)
  end
end
