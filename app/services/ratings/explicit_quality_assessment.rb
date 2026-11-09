module Ratings
  class ExplicitQualityAssessment
    attr_reader :input, :response, :result

    def initialize(expressions:, qualities:, trace_id:)
      @expressions = expressions
      @qualities = qualities
      @trace_id = trace_id
      @contract = JSON.parse(File.read(File.join(__dir__, "explicit_quality_assessment.json")))
    end

    def call(client:)
      pairs = question_pairs
      questions = pairs.transform_values do |expression_id, quality_id|
        {
          "type" => @contract.fetch("question_type"),
          "instructions" => @contract.fetch("question_template")
            .gsub("{expression_id}", expression_id).gsub("{quality_id}", quality_id),
          "criteria" => @contract.fetch("criteria")
        }
      end
      response = @response = answer(client, questions) if questions.present?
      answers = response ? response.fetch("answers") : {}
      exchanges = questions.map { |id, question| { "id" => id, "question" => question, "result" => answers.fetch(id) } }

      @result = {
        "expressions" => @expressions, "qualities" => @qualities, "calls" => exchanges.present? ? [ exchanges ] : [],
        "decisions" => decisions(pairs, answers), "question_policy" => @contract, "minimum_support" => @contract.fetch("minimum_support"),
        "configuration" => { "maximum_pairs" => @contract.fetch("maximum_pairs"), "provider" => (client.configuration if questions.present?) },
        "model" => response&.fetch("model"), "usage" => response&.fetch("usage"), "trace_id" => @trace_id
      }
      self
    end

    private

    def question_pairs
      if @expressions.size * @qualities.size > @contract.fetch("maximum_pairs")
        raise QualityAssessmentFailed.new(reason: :too_large)
      end

      @expressions.keys.product(@qualities.keys).to_h do |expression_id, quality_id|
        [ "expression_#{expression_id}_quality_#{quality_id}", [ expression_id, quality_id ] ]
      end
    end

    def answer(client, questions)
      state = { expressions: @expressions, qualities: @qualities }
      phase = "assess-explicit-quality-evidence"
      @input = { "phase" => phase, "request" => { "model" => client.configuration.fetch("model"), "state" => state, "questions" => questions } }
      client.answer(state:, questions:, phase:)
    rescue TypeSafeClient::Error => error
      raise QualityAssessmentFailed.new(reason: error.reason), cause: nil
    end

    def decisions(pairs, answers)
      pairs_by_quality = pairs.group_by { |_, (_, quality_id)| quality_id }
      @qualities.keys.map do |quality_id|
        quality_pairs = pairs_by_quality.fetch(quality_id, [])
        supporting_ids = quality_pairs.filter_map do |id, (expression_id, _)|
          expression_id.to_i if answers.fetch(id).fetch("noul") >= @contract.fetch("minimum_support")
        end
        { "quality_id" => quality_id.to_i, "applicable" => supporting_ids.present?,
          "supporting_expression_ids" => supporting_ids, "result_ids" => quality_pairs.map(&:first) }
      end
    end
  end
end
