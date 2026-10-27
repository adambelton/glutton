require "test_helper"
require Rails.root.join("lib/ai_connection_check")

class AiConnectionCheckTest < ActiveSupport::TestCase
  setup do
    @exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    @provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    @provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(@exporter))
  end

  teardown { @provider.shutdown }

  test "diagnostic records actual response usage and nested spans without authentication" do
    usage = Struct.new(:input_tokens, :output_tokens, :total_tokens).new(10, 1, 11)
    response = Struct.new(:id, :model, :status, :output_text, :usage).new("response-1", "returned-model", "completed", "OK", usage)
    requests = []
    responses = Object.new
    responses.define_singleton_method(:create) { |**request| requests << request; response }
    client = Struct.new(:responses).new(responses)
    result = AiConnectionCheck.new(client: client, provider: @provider, environment: "test").call(model: "requested-model")
    assert_equal "returned-model", result[:model]
    assert_equal false, requests.first[:store]
    assert_equal 32, requests.first[:max_output_tokens]
    generation, root = @exporter.finished_spans
    assert_equal root.span_id, generation.parent_span_id
    assert_equal root.trace_id, generation.trace_id
    assert_equal "generation", generation.attributes["langfuse.observation.type"]
    assert_equal({ "input" => 10, "output" => 1, "total" => 11 }, JSON.parse(generation.attributes["langfuse.observation.usage_details"]))
    assert_equal "returned-model", generation.attributes["langfuse.observation.model.name"]
    assert_equal "passed", JSON.parse(root.attributes["langfuse.observation.output"])["status"]
    assert generation.attributes.keys.none? { |key| key.match?(/authorization|api_key/i) }
  end

  test "request failures remain failures but secret-bearing exception text is not exported" do
    responses = Object.new
    responses.define_singleton_method(:create) { |**| raise "private request secret" }
    client = Struct.new(:responses).new(responses)
    assert_raises(RuntimeError) { AiConnectionCheck.new(client: client, provider: @provider, environment: "test").call(model: "model") }
    assert_equal 2, @exporter.finished_spans.size
    @exporter.finished_spans.each do |span|
      assert_equal OpenTelemetry::Trace::Status::ERROR, span.status.code
      assert_empty Array(span.events)
      assert_not_includes span.status.description, "private request secret"
    end
  end
end
