require "base64"
require "uri"
require "openai"
require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"

module AiConfiguration
  def self.openai_client(env: ENV)
    key = env["OPENAI_API_KEY"]
    return if key.nil? || key.strip.empty?

    OpenAI::Client.new(api_key: key, timeout: 60, max_retries: 0)
  end

  def self.langfuse_options(env: ENV, environment:)
    return if environment == "test" || env["LANGFUSE_TRACING_ENABLED"] == "false"

    values = %w[LANGFUSE_BASE_URL LANGFUSE_PUBLIC_KEY LANGFUSE_SECRET_KEY].map { |key| env[key].to_s.strip }
    return if values.all?(&:empty?)
    raise ArgumentError, "Langfuse requires base URL, public key and secret key" if values.any?(&:empty?)

    base_url, public_key, secret_key = values
    uri = URI.parse(base_url)
    local_http = uri.scheme == "http" && %w[localhost 127.0.0.1 ::1].include?(uri.host)
    unless (uri.scheme == "https" || local_http) && uri.host && !uri.userinfo && !uri.query && !uri.fragment
      raise ArgumentError, "Langfuse requires an HTTPS base URL (HTTP allowed only on localhost)"
    end

    {
      endpoint: "#{base_url.delete_suffix('/')}/api/public/otel/v1/traces",
      headers: {
        "Authorization" => "Basic #{Base64.strict_encode64("#{public_key}:#{secret_key}")}",
        "x-langfuse-ingestion-version" => "4"
      },
      timeout: 5
    }
  rescue URI::InvalidURIError
    raise ArgumentError, "Langfuse base URL is invalid"
  end

  def self.tracer_provider(options:, environment:)
    return unless options

    exporter = OpenTelemetry::Exporter::OTLP::Exporter.new(**options)
    processor = OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(exporter, exporter_timeout: 5_000)
    resource = OpenTelemetry::SDK::Resources::Resource.create(
      "service.name" => "glutton", "deployment.environment.name" => environment
    )
    provider = OpenTelemetry::SDK::Trace::TracerProvider.new(resource: resource)
    provider.add_span_processor(processor)
    provider
  end
end
