module Ratings
  class ExplicitQualityAssessment
    attr_reader :provider_calls, :result

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
      configuration = client.configuration if questions.present?
      @provider_calls = []
      answers = {}
      exchanges = if questions.present?
        batches(pairs, questions, configuration).map do |request|
          response = answer(client, request)
          answers.merge!(response.fetch("answers"))
          request.fetch("questions").map do |id, question|
            { "id" => id, "question" => question, "result" => answers.fetch(id) }
          end
        end
      else
        []
      end
      responses = @provider_calls.pluck("response")

      @result = {
        "expressions" => @expressions, "qualities" => @qualities, "calls" => exchanges,
        "decisions" => decisions(pairs, answers), "question_policy" => @contract, "minimum_support" => @contract.fetch("minimum_support"),
        "configuration" => { "maximum_pairs" => @contract.fetch("maximum_pairs"), "provider" => configuration },
        "model" => responses.last&.fetch("model"), "usage" => combined_usage(responses), "trace_id" => @trace_id
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

    def batches(pairs, questions, configuration)
      expression_ids = pairs.values.map(&:first).uniq
      state = { expressions: @expressions.slice(*expression_ids), qualities: @qualities }
      request = { "model" => configuration.fetch("model"), "state" => state, "questions" => questions }
      maximum_bytes = configuration.fetch("maximum_request_bytes", Float::INFINITY)
      return [ request ] if JSON.generate(request).bytesize <= maximum_bytes
      raise QualityAssessmentFailed.new(reason: :too_large) if expression_ids.one?

      left_ids = expression_ids.take(expression_ids.size / 2).to_set
      left, right = pairs.partition { |_, (expression_id, _)| left_ids.include?(expression_id) }
      [ left.to_h, right.to_h ].flat_map { |group| batches(group, questions.slice(*group.keys), configuration) }
    end

    def answer(client, request)
      phase = "assess-explicit-quality-evidence"
      response = client.answer(state: request.fetch("state"), questions: request.fetch("questions"), phase:)
      @provider_calls << { "phase" => phase, "request" => request, "response" => response }
      response
    rescue TypeSafeClient::Error => error
      raise QualityAssessmentFailed.new(reason: error.reason), cause: nil
    end

    def combined_usage(responses)
      return if responses.empty?

      %w[input_tokens output_tokens].index_with do |key|
        responses.sum { |response| response.fetch("usage").fetch(key) }
      end
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
