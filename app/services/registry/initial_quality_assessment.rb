module Registry
  class InitialQualityAssessment
    MODEL = "jev-1.14.0".freeze
    POLICY = "support-0.60-category-cap-id-ties-v1".freeze
    EVIDENCE_POLICY = "strongest-source-paragraph-v1".freeze
    MINIMUM_SUPPORT = 0.60
    EVIDENCE_BATCH_SIZE = 4

    attr_reader :result

    def initialize(source:, definitions:, categories:, trace_id: nil)
      @source, @definitions, @categories = source, definitions, categories
      @contract = JSON.parse(Rails.root.join("docs/film_qualities/matching.json").read)
      @trace_id = trace_id
      @calls, @support, @evidence, @selected_quality_ids = [], {}, {}, []
      @selection_decisions = []
    end

    def call(client:)
      state = {
        "film_title" => source.fetch("title"),
        "source_paragraphs" => source.fetch("wikipedia_context").fetch("source_paragraphs"),
        "evidence_policy" => @contract.fetch("evidence_policy")
      }
      questions = definitions.to_h do |definition|
        [ question_id(definition), {
          "type" => "noul",
          "instructions" => @contract.fetch("question_template").gsub("{name}", definition.fetch("name")),
          "criteria" => { "true" => definition.fetch("match_rule"),
            "false" => @contract.fetch("false_criterion_template").gsub("{not_sufficient}", definition.fetch("not_sufficient")) }
        } ]
      end
      response = answer(client:, state:, questions:, phase: "quality-support")
      definitions.each { |definition| @support[definition.fetch("id").to_s] = response.fetch("answers").fetch(question_id(definition)).fetch("noul") }
      @selection_decisions = selection_decisions
      definitions_by_id = definitions.index_by { |definition| definition.fetch("id") }
      selected = @selection_decisions.select { |decision| decision.fetch("selected") }
        .map { |decision| definitions_by_id.fetch(decision.fetch("quality_id")) }
      selected.each_slice(EVIDENCE_BATCH_SIZE) do |batch|
        criteria = state.fetch("source_paragraphs").to_h { |paragraph| [ paragraph.fetch("id"), "Source paragraph #{paragraph.fetch('id')} under #{paragraph['section'] || 'the introduction'}" ] }
        questions = batch.to_h do |definition|
          [ question_id(definition), {
            "type" => "choice",
            "instructions" => {
              "question" => "Which supplied source paragraph most directly supports #{definition.fetch('name')}?",
              "definition" => definition.fetch("match_rule"), "not_sufficient" => definition.fetch("not_sufficient")
            }, "criteria" => criteria
          } ]
        end
        response = answer(client:, state:, questions:, phase: "quality-evidence")
        batch.each do |definition|
          @evidence[definition.fetch("id").to_s] = [ response.fetch("answers").fetch(question_id(definition)).fetch("choice") ]
        end
      end
      @selected_quality_ids = selected.map { |definition| definition.fetch("id") }
      @result = build_result.merge("status" => "completed")
      self
    rescue AssignmentFailed => error
      @result = build_result.merge("status" => "failed", "error" => { "reason" => error.reason.to_s })
      raise
    rescue StandardError
      @result = build_result.merge("status" => "failed", "error" => { "reason" => "unexpected_failure" })
      raise
    end

    private

    attr_reader :source, :definitions, :categories

    def answer(client:, state:, questions:, phase:)
      call = { "phase" => phase, "started_at" => Time.current.utc.iso8601,
        "request" => { "model" => MODEL, "state" => state, "questions" => questions } }
      @calls << call
      response = client.answer(state:, questions:, phase:)
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

    def build_result
      input_tokens = @calls.select { |call| call.fetch("status") == "completed" }
        .sum { |call| call.fetch("response").fetch("usage").fetch("input_tokens") }
      {
        "assessed_at" => Time.current.utc.iso8601, "source" => source,
        "definitions" => definitions, "categories" => categories,
        "question_policy" => @contract, "selection_policy" => POLICY, "evidence_policy" => EVIDENCE_POLICY,
        "minimum_support" => MINIMUM_SUPPORT,
        "model" => MODEL, "trace_id" => @trace_id, "support" => @support, "evidence" => @evidence,
        "selected_quality_ids" => @selected_quality_ids,
        "calls" => @calls, "call_count" => @calls.count { |call| call.fetch("status") != "not_sent" },
        "selection_decisions" => @selection_decisions,
        "usage_complete" => @calls.all? { |call| call.fetch("status") == "completed" },
        "input_tokens" => input_tokens,
        "calculated_cost_usd" => input_tokens * TypeSafeClient::INPUT_TOKEN_PRICE
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
          supported = @support.fetch(quality_id.to_s) >= MINIMUM_SUPPORT
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
