require "fileutils"
require "securerandom"

module FilmKnowledge
  class GenerateAnalysis
    attr_reader :artifact_path

    def initialize(client: Rails.application.config.x.openai_client,
      provider: Rails.application.config.x.langfuse_tracer_provider, prompt_source: AnalysisPrompt)
      @client, @provider, @prompt_source = client, provider, prompt_source
    end

    def call(film:, model:, max_output_tokens:, output_directory:, version: nil, label: nil)
      @artifact = @artifact_path = nil
      raise ArgumentError, "Configure OpenAI and choose a model and positive output cap" unless @client && model.is_a?(String) && model.present? && max_output_tokens.is_a?(Integer) && max_output_tokens.positive?
      FileUtils.mkdir_p(output_directory)
      @artifact_path = File.join(output_directory, "#{SecureRandom.uuid}.json")
      @artifact = { "film_id" => film.id, "outcome" => "started", "started_at" => Time.current.utc.iso8601(6) }
      # Reserve the output before any paid operation; never overwrite another run.
      File.open(artifact_path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(JSON.pretty_generate(@artifact)) }
      tracer = (@provider || OpenTelemetry.tracer_provider).tracer("glutton.film-analysis", "1")
      tracer.in_span("generate-film-analysis", attributes: common_attributes, record_exception: false) do |root|
        @artifact["trace_id"] = root.context.hex_trace_id
        begin
          film = Film.find(film.id)
          raise GenerationUnavailable unless film.can_generate_analysis?
          input = film.analysis_generation_input
          source = input.fetch(:sources).sole
          vocabulary = input.fetch(:existing_vocabulary)
          @artifact["input"] = input
          root.set_attribute("langfuse.observation.input", input.to_json)
          tracer.in_span("retrieve-film-analysis-prompt", attributes: common_attributes, record_exception: false) do
            @artifact["prompt"] = @prompt_source.call(version:, label:)
          end
          prompt = @artifact.fetch("prompt")
          request = { model:, max_output_tokens:, store: false, instructions: prompt.fetch("prompt"), input: input.to_json,
            text: { format: { type: "json_schema", name: "film_analysis", strict: true, schema: GeneratedAnalysis.schema } } }
          @artifact["request"] = request
          response = generate(tracer, request, prompt)
          attributes = tracer.in_span("validate-film-analysis", attributes: common_attributes, record_exception: false) do
            GeneratedAnalysis.parse!(response.output_text, source:, vocabulary:)
          end
          analysis = film.save_generated_analysis!(**attributes)
          @artifact.merge!("outcome" => "saved", "analysis_id" => analysis.id)
          root.set_attribute("langfuse.observation.output", { outcome: "saved", analysis_id: analysis.id }.to_json)
          analysis
        rescue GenerationUnavailable => error
          record_failure(root, error, outcome: "generation_unavailable")
          raise
        rescue GenerationFailed => error
          record_failure(root, error, outcome: error.reason.to_s)
          raise
        rescue StandardError => error
          record_failure(root, error, outcome: "failed")
          raise
        end
      end
    ensure
      if @artifact
        begin
          @artifact["trace_export"] = @provider ? (@provider.force_flush(timeout: 5) == OpenTelemetry::SDK::Trace::Export::SUCCESS ? "flushed" : "failed") : "disabled"
        rescue StandardError
          @artifact["trace_export"] = "failed"
        end
        @artifact["completed_at"] = Time.current.utc.iso8601(6)
        File.write(artifact_path, JSON.pretty_generate(@artifact))
      end
    end

    private

    def record_failure(root, error, outcome:)
      @artifact["outcome"] = outcome
      @artifact["error_class"] = error.class.name
      root.set_attribute("langfuse.observation.output", @artifact.slice("outcome", "error_class").to_json)
      root.status = OpenTelemetry::Trace::Status.error(outcome)
    end

    def common_attributes
      { "langfuse.environment" => Rails.env.to_s, "langfuse.trace.tags" => [ "film-analysis" ], "langfuse.version" => "1" }
    end

    def generate(tracer, request, prompt)
      tracer.in_span("generate-film-analysis-response", attributes: common_attributes.merge(
        "langfuse.observation.type" => "generation",
        "langfuse.observation.prompt.name" => prompt.fetch("name"),
        "langfuse.observation.prompt.version" => prompt.fetch("version"),
        "langfuse.observation.model.name" => request[:model],
        "langfuse.observation.model.parameters" => request.slice(:max_output_tokens, :store, :text).to_json,
        "langfuse.observation.input" => request.slice(:instructions, :input).to_json
      ), record_exception: false) do |span|
        response = @client.responses.create(**request)
        @artifact["response"] = response.to_h
        span.set_attribute("langfuse.observation.output", response.output_text.to_json)
        span.set_attribute("langfuse.observation.model.name", response.model) if response.model
        span.set_attribute("langfuse.observation.metadata.response_status", response.status.to_s)
        if response.usage
          span.set_attribute("langfuse.observation.usage_details", { input: response.usage.input_tokens,
            output: response.usage.output_tokens, total: response.usage.total_tokens }.to_json)
        end
        raise GenerationFailed.new(:incomplete_response) unless response.status.to_s == "completed"
        output = JSON.parse(response.to_h.to_json).fetch("output", [])
        if output.any? { |item| item["type"] == "message" && Array(item["content"]).any? { |part| part["type"] == "refusal" } }
          raise GenerationFailed.new(:refused_response)
        end
        response
      rescue StandardError => error
        span.status = OpenTelemetry::Trace::Status.error(error.class.name)
        raise
      end
    end
  end
end
