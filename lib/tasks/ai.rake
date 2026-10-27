namespace :ai do
  desc "Send a small real OpenAI request and export its diagnostic trace to Langfuse"
  task check: :environment do
    require Rails.root.join("lib/ai_connection_check")
    result = AiConnectionCheck.new(
      client: Rails.application.config.x.openai_client,
      provider: Rails.application.config.x.langfuse_tracer_provider,
      environment: Rails.env.to_s
    ).call(model: ENV["OPENAI_MODEL"])
    puts JSON.pretty_generate(result)
  rescue StandardError => error
    # API exceptions may contain request content. Do not dump them into the terminal.
    abort "AI connection check failed (#{error.class}); check configuration and the diagnostic trace."
  end
end
