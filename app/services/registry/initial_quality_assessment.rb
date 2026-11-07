module Registry
  class InitialQualityAssessment
    attr_reader :result

    def initialize(source:, definitions:, categories:, trace_id: nil)
      @source, @definitions, @categories = source, definitions, categories
      @contract = JSON.parse(File.read(File.join(__dir__, "initial_quality_assessment.json")))
      @trace_id = trace_id
      @calls, @support, @selected_quality_ids = [], {}, []
      @selection_decisions = []
    end

    def call(client:)
      available_state = {
        "film_title" => source.fetch("title"),
        "source_paragraphs" => source.fetch("wikipedia_context").fetch("source_paragraphs"),
        "evidence_policy" => @contract.fetch("evidence_policy")
      }
      state = @contract.fetch("state_fields").index_with { |field| available_state.fetch(field) }
      questions = definitions.to_h do |definition|
        [ question_id(definition), {
          "type" => @contract.fetch("question_type"),
          "instructions" => @contract.fetch("question_template").gsub("{name}", definition.fetch("name")),
          "criteria" => { "true" => definition.fetch(@contract.fetch("true_criterion_field")),
            "false" => @contract.fetch("false_criterion_template").gsub("{not_sufficient}", definition.fetch("not_sufficient")) }
        } ]
      end
      response = answer(client:, state:, questions:, phase: "quality-support")
      definitions.each { |definition| @support[definition.fetch("id").to_s] = response.fetch("answers").fetch(question_id(definition)).fetch("noul") }
      @selection_decisions = selection_decisions
      @selected_quality_ids = @selection_decisions.select { |decision| decision.fetch("selected") }
        .map { |decision| decision.fetch("quality_id") }
      @result = build_result(client).merge("status" => "completed")
      self
    rescue AssignmentFailed => error
      @result = build_result(client).merge("status" => "failed", "error" => { "reason" => error.reason.to_s })
      raise
    rescue StandardError
      @result = build_result(client).merge("status" => "failed", "error" => { "reason" => "unexpected_failure" })
      raise
    end

    private

    attr_reader :source, :definitions, :categories

    def answer(client:, state:, questions:, phase:)
      call = { "phase" => phase, "started_at" => Time.current.utc.iso8601,
        "request" => { "model" => client.model, "state" => state, "questions" => questions } }
      @calls << call
      response = request_answers(client, state:, questions:, phase:)
      call.merge!("status" => "completed", "response" => response)
      response
    rescue AssignmentFailed => error
      call.merge!("status" => error.request_sent == false ? "not_sent" : "failed",
        "error" => { "reason" => error.reason.to_s })
      call["response"] = error.provider_response unless error.provider_response.nil?
      raise
    rescue StandardError
      call.merge!("status" => "failed", "error" => { "reason" => "unexpected_failure" })
      raise
    ensure
      call["finished_at"] = Time.current.utc.iso8601
    end

    def request_answers(client, state:, questions:, phase:)
      client.answer(state:, questions:, phase:)
    rescue TypeSafeClient::Error => error
      raise AssignmentFailed.new(reason: error.reason, provider_response: error.provider_response,
        request_sent: error.request_sent), cause: nil
    end

    def build_result(client)
      completed_calls = @calls.select { |call| call.fetch("status") == "completed" }
      input_tokens = completed_calls.sum { |call| call.fetch("response").fetch("usage").fetch("input_tokens") }
      {
        "assessed_at" => Time.current.utc.iso8601, "source" => source,
        "definitions" => definitions, "categories" => categories,
        "question_policy" => @contract,
        "minimum_support" => @contract.fetch("minimum_support"), "configuration" => { "provider" => client.configuration },
        "model" => completed_calls.last&.dig("response", "model") || client.model, "trace_id" => @trace_id, "support" => @support, "evidence" => {},
        "selected_quality_ids" => @selected_quality_ids,
        "calls" => @calls, "call_count" => @calls.count { |call| call.fetch("status") != "not_sent" },
        "selection_decisions" => @selection_decisions,
        "usage_complete" => @calls.all? { |call| call.fetch("status") == "completed" },
        "input_tokens" => input_tokens,
        "calculated_cost_usd" => client.input_cost(input_tokens:)
      }
    end

    def question_id(definition)
      "quality_#{definition.fetch('id')}"
    end

    def selection_decisions
      categories.flat_map do |category|
        ranked = definitions.select { |definition| definition.fetch("quality_category_id") == category.fetch("id") }
          .sort_by { |definition| [ -@support.fetch(definition.fetch("id").to_s), definition.fetch("id") ] }
        ranked.each_with_index.map do |definition, index|
          quality_id = definition.fetch("id")
          supported = @support.fetch(quality_id.to_s) >= @contract.fetch("minimum_support")
          selected = supported && index < category.fetch("maximum_qualities")
          { "quality_id" => quality_id, "quality_category_id" => category.fetch("id"),
            "support" => @support.fetch(quality_id.to_s), "rank" => index + 1,
            "maximum_qualities" => category.fetch("maximum_qualities"), "selected" => selected,
            "reason" => supported ? (selected ? "selected" : "category_ceiling") : "below_threshold" }
        end
      end
    end
  end
end
