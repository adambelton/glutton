class TypeSafeClient
  CONFIGURATION = JSON.parse(Rails.root.join("config/typesafe.json").read).freeze

  TRACE_TAGS = OpenTelemetry::Context.create_key("glutton.typesafe.trace_tags")
  private_constant :TRACE_TAGS

  def self.with_trace_tags(tags, &block)
    OpenTelemetry::Context.with_value(TRACE_TAGS, tags, &block)
  end

  class Error < StandardError
    attr_reader :reason, :provider_response, :request_sent

    def initialize(reason:, provider_response: nil, request_sent: nil)
      @reason, @provider_response, @request_sent = reason, provider_response, request_sent
      super("TypeSafe request failed (#{reason})")
    end
  end

  def initialize(token: ENV["TYPESAFE_API_KEY"], http_class: Net::HTTP,
    tracer: OpenTelemetry::Trace::TracerProvider.new.tracer("glutton.typesafe"),
    profile: nil, maximum_requests: nil, maximum_cost_usd: nil, maximum_request_bytes: nil,
    maximum_response_bytes: nil, trace_payload: nil)
    @token, @tracer = token, tracer
    defaults = CONFIGURATION.fetch("defaults")
    defaults = defaults.merge(CONFIGURATION.fetch(profile.to_s)) if profile.present?
    @settings = defaults.merge({
      "maximum_requests" => maximum_requests, "maximum_cost_usd" => maximum_cost_usd,
      "maximum_request_bytes" => maximum_request_bytes, "maximum_response_bytes" => maximum_response_bytes,
      "trace_payload" => trace_payload
    }.compact)
    @requests, @cost = 0, 0.0
    @request = ProviderRequest.new(host: "api.typesafe.ai", maximum_bytes: @settings.fetch("maximum_response_bytes"),
      http_class:, read_timeout: CONFIGURATION.fetch("read_timeout_seconds"),
      request_timeout: CONFIGURATION.fetch("request_timeout_seconds"))
  end

  def model
    CONFIGURATION.fetch("model")
  end

  def configuration
    CONFIGURATION.slice("model", "input_token_price_usd", "read_timeout_seconds", "request_timeout_seconds")
      .merge(@settings).merge("maximum_cost_usd" => @settings.fetch("maximum_cost_usd").to_f)
  end

  def input_cost(input_tokens:)
    input_tokens * CONFIGURATION.fetch("input_token_price_usd")
  end

  def answer(state:, questions:, phase:)
    request_sent, response = false, nil
    fail_request(:configuration) unless @token.is_a?(String) && @token.present? && !@token.match?(/[\r\n]/)
    payload = { "model" => model, "state" => state, "questions" => questions }
    bytes = JSON.generate(payload).bytesize
    fail_request(:too_large) if bytes > @settings.fetch("maximum_request_bytes")
    fail_request(:request_limit) if @requests >= @settings.fetch("maximum_requests")
    # Conservative preflight allowance; use actual billable input tokens after each response.
    fail_request(:budget_exceeded) if @cost + input_cost(input_tokens: bytes * 2 + 4096) > @settings.fetch("maximum_cost_usd")
    @requests += 1
    allowance = input_cost(input_tokens: bytes * 2 + 4096)
    @cost += allowance
    @tracer.in_span(phase, attributes: {
      "langfuse.observation.type" => "generation",
      "langfuse.environment" => Rails.env.to_s,
      "langfuse.trace.tags" => OpenTelemetry::Context.value(TRACE_TAGS),
      "langfuse.observation.model.name" => model,
      "langfuse.observation.input" => (@settings.fetch("trace_payload") ? payload : { question_count: questions.size }).to_json
    }.compact, record_exception: false) do |span|
      request_sent = true
      response = @request.post(path: "/v1/systemone", payload:, headers: { "Authorization" => "Bearer #{@token}" })
      validate_response!(response:, questions:)
      usage = response.fetch("usage")
      @cost += input_cost(input_tokens: usage.fetch("input_tokens")) - allowance
      span.set_attribute("langfuse.observation.output", response.to_json) if @settings.fetch("trace_payload")
      span.set_attribute("langfuse.observation.usage_details", { input: usage.fetch("input_tokens"), output: usage.fetch("output_tokens") }.to_json)
      span.set_attribute("langfuse.observation.cost_details", { input: input_cost(input_tokens: usage.fetch("input_tokens")) }.to_json)
    rescue Error, ProviderRequest::Error
      span.status = OpenTelemetry::Trace::Status.error("Assessment request failed")
      span.set_attribute("langfuse.observation.level", "ERROR")
      raise
    end
    response
  rescue Error, ProviderRequest::Error => error
    raise Error.new(reason: error.reason, provider_response: response, request_sent:), cause: nil
  end

  private

  def validate_response!(response:, questions:)
    fail_request(:invalid_response) unless response.is_a?(Hash)
    fail_request(:unsupported_model) unless response["model"] == model
    usage, answers = response["usage"], response["answers"]
    unless usage.is_a?(Hash) && %w[input_tokens output_tokens].all? { |key| usage[key].is_a?(Integer) && usage[key] >= 0 } &&
        answers.is_a?(Hash) && answers.size == questions.size && questions.keys.all? { |id| answers.key?(id) }
      fail_request(:invalid_response)
    end
    questions.each do |id, question|
      answer = answers.fetch(id)
      fail_request(:invalid_response) unless answer.is_a?(Hash) && answer["type"] == question.fetch("type")
      case question.fetch("type")
      when "noul"
        fail_request(:invalid_response) unless probability?(answer["noul"])
      when "choice"
        probabilities = answer["probabilities"]
        unless question.fetch("criteria").key?(answer["choice"]) && probabilities.is_a?(Hash) &&
            probabilities.keys.sort == question.fetch("criteria").keys.sort && probabilities.values.all? { |value| probability?(value) }
          fail_request(:invalid_response)
        end
      end
    end
  end

  def probability?(value)
    value.is_a?(Numeric) && value.finite? && value.between?(0, 1)
  end

  def fail_request(reason)
    raise Error.new(reason:), cause: nil
  end
end
