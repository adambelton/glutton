require Rails.root.join("lib/ai_configuration")

# Dotenv has loaded before initializers. Construction performs no API requests.
Rails.application.config.x.openai_client = AiConfiguration.openai_client unless Rails.env.test?

begin
  options = AiConfiguration.langfuse_options(environment: Rails.env.to_s)
  provider = AiConfiguration.tracer_provider(options: options, environment: Rails.env.to_s)
  Rails.application.config.x.langfuse_tracer_provider = provider
  # Keep this provider isolated: Rails requests, SQL and HTTP headers are not exported.
  at_exit { provider.shutdown(timeout: 5) } if provider
rescue ArgumentError
  Rails.logger.warn("Langfuse tracing disabled: invalid or incomplete configuration")
end
