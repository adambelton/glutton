require "test_helper"
require Rails.root.join("lib/ai_configuration")

class AiConfigurationTest < ActiveSupport::TestCase
  test "no credentials or test environment disables export" do
    assert_nil AiConfiguration.langfuse_options(env: {}, environment: "development")
    assert_nil AiConfiguration.langfuse_options(env: credentials, environment: "test")
    assert_nil AiConfiguration.langfuse_options(env: credentials.merge("LANGFUSE_TRACING_ENABLED" => "false"), environment: "production")
    assert_nil AiConfiguration.openai_client(env: {})
  end

  test "OTLP authenticates only to a validated endpoint with a bounded timeout" do
    options = AiConfiguration.langfuse_options(env: credentials, environment: "development")
    assert_equal "https://example.com/api/public/otel/v1/traces", options[:endpoint]
    assert_equal "Basic #{Base64.strict_encode64('public:secret')}", options[:headers]["Authorization"]
    assert_equal "4", options[:headers]["x-langfuse-ingestion-version"]
    assert_equal 5, options[:timeout]
  end

  test "partial configuration and insecure remote endpoints fail without revealing credentials" do
    [ credentials.except("LANGFUSE_PUBLIC_KEY"), credentials.merge("LANGFUSE_BASE_URL" => "http://example.com"),
      credentials.merge("LANGFUSE_BASE_URL" => "https://secret@example.com"),
      credentials.merge("LANGFUSE_BASE_URL" => "https://example.com?key=secret") ].each do |env|
      error = assert_raises(ArgumentError) { AiConfiguration.langfuse_options(env: env, environment: "development") }
      assert_not_includes error.message, "secret@example"
      assert_not_includes error.message, "key=secret"
    end
  end

  test "OpenAI uses a bounded single attempt" do
    client = AiConfiguration.openai_client(env: { "OPENAI_API_KEY" => "test-key" })
    assert_equal 60, client.timeout
    assert_equal 0, client.max_retries
  end

  private

  def credentials
    { "LANGFUSE_BASE_URL" => "https://example.com/", "LANGFUSE_PUBLIC_KEY" => "public", "LANGFUSE_SECRET_KEY" => "secret" }
  end
end
