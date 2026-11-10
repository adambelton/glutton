module Ratings
  class ExplicitQualityAssessment
    attr_reader :provider_calls, :result

    def initialize(notes:, qualities:, trace_id:)
      @notes = notes
      @qualities = qualities
      @trace_id = trace_id
      @contract = JSON.parse(File.read(File.join(__dir__, "explicit_quality_assessment.json")))
    end

    def call(client:)
      pairs = question_pairs
      questions = pairs.transform_values do |rating_id, quality_id|
        {
          "type" => @contract.fetch("question_type"),
          "instructions" => @contract.fetch("question_template")
            .gsub("{rating_id}", rating_id).gsub("{quality_id}", quality_id),
          "criteria" => @contract.fetch("criteria")
        }
      end
      configuration = client.configuration if questions.present?
      @provider_calls = []
      answers = {}
      exchanges = []
      if questions.present?
        request = { "model" => configuration.fetch("model"),
          "state" => { notes: @notes, qualities: @qualities }, "questions" => questions }
        response = answer(client, request)
        answers = response.fetch("answers")
        exchanges << questions.map do |id, question|
          { "id" => id, "question" => question, "result" => answers.fetch(id) }
        end
      end

      @result = {
        "notes" => @notes, "qualities" => @qualities, "calls" => exchanges,
        "decisions" => decisions(pairs, answers), "question_policy" => @contract, "minimum_support" => @contract.fetch("minimum_support"),
        "configuration" => { "maximum_pairs" => @contract.fetch("maximum_pairs"), "provider" => configuration },
        "model" => response&.fetch("model"), "usage" => response&.fetch("usage"), "trace_id" => @trace_id
      }
      self
    end

    private

    def question_pairs
      if @notes.size * @qualities.size > @contract.fetch("maximum_pairs")
        raise QualityAssessmentFailed.new(reason: :too_large)
      end

      @notes.keys.product(@qualities.keys).to_h do |rating_id, quality_id|
        [ "notes_#{rating_id}_quality_#{quality_id}", [ rating_id, quality_id ] ]
      end
    end

    def answer(client, request)
      phase = "assess-explicit-quality-evidence"
      response = client.answer(state: request.fetch("state"), questions: request.fetch("questions"), phase:)
      @provider_calls << { "phase" => phase, "request" => request, "response" => response }
      response
    rescue TypeSafeClient::Error => error
      raise QualityAssessmentFailed.new(reason: error.reason), cause: nil
    end

    def decisions(pairs, answers)
      pairs_by_quality = pairs.group_by { |_, (_, quality_id)| quality_id }
      @qualities.keys.map do |quality_id|
        quality_pairs = pairs_by_quality.fetch(quality_id, [])
        supporting_ids = quality_pairs.filter_map do |id, (rating_id, _)|
          rating_id.to_i if answers.fetch(id).fetch("noul") >= @contract.fetch("minimum_support")
        end
        { "quality_id" => quality_id.to_i, "applicable" => supporting_ids.present?,
          "supporting_rating_ids" => supporting_ids, "result_ids" => quality_pairs.map(&:first) }
      end
    end
  end
end
