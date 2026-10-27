# Run with bin/rails runner script/check_film_analysis_prompt.rb.
# This sends one small real request, using the development prompt and no film evidence.
require "json"
require "open3"
output, _errors, status = Open3.capture3(
  { "LANGFUSE_HOST" => ENV.fetch("LANGFUSE_BASE_URL") },
  "npx", "--yes", "langfuse-cli", "api", "prompts", "get", "film-analysis", "--label", "development", "--json"
)
abort "Prompt retrieval failed" unless status.success?
prompt = JSON.parse(output).fetch("body")
abort "Expected the film-analysis text prompt" unless prompt["name"] == "film-analysis" && prompt["type"] == "text"
model = ENV.fetch("OPENAI_MODEL")
provider = Rails.application.config.x.langfuse_tracer_provider
client = Rails.application.config.x.openai_client
abort "Configure both OpenAI and Langfuse" unless provider && client
input = JSON.generate({ film: nil, sources: [], existing_vocabulary: [] })
tracer = provider.tracer("glutton.film-analysis.prompt-check", "1")
result = nil
begin
  tracer.in_span("check-film-analysis-prompt", attributes: {
    "langfuse.observation.type" => "generation",
    "langfuse.environment" => "development",
    "langfuse.trace.tags" => [ "prompt-wiring-check" ],
    "langfuse.observation.prompt.name" => prompt.fetch("name"),
    "langfuse.observation.prompt.version" => prompt.fetch("version"),
    "langfuse.observation.model.name" => model,
    "langfuse.observation.model.parameters" => { max_output_tokens: 512, store: false }.to_json,
    "langfuse.observation.input" => { instructions: prompt.fetch("prompt"), input: input }.to_json
  }, record_exception: false) do |span|
    response = client.responses.create(model: model, instructions: prompt.fetch("prompt"), input: input, max_output_tokens: 512, store: false)
    span.set_attribute("langfuse.observation.output", response.output_text.to_json)
    span.set_attribute("langfuse.observation.model.name", response.model)
    span.set_attribute("langfuse.observation.metadata.response_status", response.status.to_s)
    span.set_attribute("langfuse.observation.usage_details", { input: response.usage.input_tokens, output: response.usage.output_tokens, total: response.usage.total_tokens }.to_json)
    result = { trace_id: span.context.hex_trace_id, status: response.status, output: response.output_text }
  end
rescue StandardError => error
  abort "Prompt check failed (#{error.class}); inspect the diagnostic trace"
ensure
  provider.force_flush(timeout: 5)
end
puts JSON.pretty_generate(result)
