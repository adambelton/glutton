module FilmKnowledge
  class TypeSafeClient
    INPUT_TOKEN_PRICE = 0.042 / 1_000_000
    MAXIMUM_REQUEST_BYTES = 512.kilobytes

    def initialize(token: ENV["TYPESAFE_API_KEY"], http_class: Net::HTTP,
      tracer: OpenTelemetry::Trace::TracerProvider.new.tracer("glutton.film-knowledge"),
      maximum_requests: 64, maximum_cost_usd: 0.02)
      @token, @tracer = token, tracer
      @maximum_requests, @maximum_cost_usd = maximum_requests, maximum_cost_usd
      @requests, @cost = 0, 0.0
      @request = ProviderRequest.new(host: "api.typesafe.ai", maximum_bytes: 8.megabytes,
        http_class:, read_timeout: 60, request_timeout: 90)
    end

    def answer(state:, questions:, phase:)
      request_sent, response = false, nil
      fail_assignment(:configuration) unless @token.is_a?(String) && @token.present? && !@token.match?(/[\r\n]/)
      payload = { "model" => InitialQualityAssessment::MODEL, "state" => state, "questions" => questions }
      bytes = JSON.generate(payload).bytesize
      fail_assignment(:too_large) if bytes > MAXIMUM_REQUEST_BYTES
      fail_assignment(:request_limit) if @requests >= @maximum_requests
      # Conservative preflight allowance; use actual billable input tokens after each response.
      fail_assignment(:budget_exceeded) if @cost + (bytes * 2 + 4096) * INPUT_TOKEN_PRICE > @maximum_cost_usd
      @requests += 1
      allowance = (bytes * 2 + 4096) * INPUT_TOKEN_PRICE
      @cost += allowance
      @tracer.in_span(phase, attributes: {
        "langfuse.observation.type" => "generation",
        "langfuse.observation.model.name" => InitialQualityAssessment::MODEL,
        "langfuse.observation.input" => payload.to_json
      }, record_exception: false) do |span|
        request_sent = true
        response = @request.post(path: "/v1/systemone", payload:, headers: { "Authorization" => "Bearer #{@token}" })
        validate_response!(response:, questions:)
        usage = response.fetch("usage")
        @cost += usage.fetch("input_tokens") * INPUT_TOKEN_PRICE - allowance
        span.set_attribute("langfuse.observation.output", response.to_json)
        span.set_attribute("langfuse.observation.usage_details", { input: usage.fetch("input_tokens"), output: usage.fetch("output_tokens") }.to_json)
        span.set_attribute("langfuse.observation.cost_details", { input: usage.fetch("input_tokens") * INPUT_TOKEN_PRICE }.to_json)
      rescue AssignmentFailed, ProviderRequest::Error
        span.status = OpenTelemetry::Trace::Status.error("Assessment request failed")
        span.set_attribute("langfuse.observation.level", "ERROR")
        raise
      end
      response
    rescue AssignmentFailed, ProviderRequest::Error => error
      raise AssignmentFailed.new(reason: error.reason, provider_response: response, request_sent:), cause: nil
    end

    private

    def validate_response!(response:, questions:)
      fail_assignment(:invalid_response) unless response.is_a?(Hash)
      fail_assignment(:unsupported_model) unless response["model"] == InitialQualityAssessment::MODEL
      usage, answers = response["usage"], response["answers"]
      unless usage.is_a?(Hash) && %w[input_tokens output_tokens].all? { |key| usage[key].is_a?(Integer) && usage[key] >= 0 } &&
          answers.is_a?(Hash) && answers.keys.sort == questions.keys.sort
        fail_assignment(:invalid_response)
      end
      questions.each do |id, question|
        answer = answers.fetch(id)
        fail_assignment(:invalid_response) unless answer.is_a?(Hash) && answer["type"] == question.fetch("type")
        case question.fetch("type")
        when "noul"
          fail_assignment(:invalid_response) unless probability?(answer["noul"])
        when "choice"
          probabilities = answer["probabilities"]
          unless question.fetch("criteria").key?(answer["choice"]) && probabilities.is_a?(Hash) &&
              probabilities.keys.sort == question.fetch("criteria").keys.sort && probabilities.values.all? { |value| probability?(value) }
            fail_assignment(:invalid_response)
          end
        end
      end
    end

    def probability?(value)
      value.is_a?(Numeric) && value.finite? && value.between?(0, 1)
    end

    def fail_assignment(reason)
      raise AssignmentFailed.new(reason:), cause: nil
    end
  end
end
