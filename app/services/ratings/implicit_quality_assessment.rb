module Ratings
  class ImplicitQualityAssessment
    attr_reader :input, :response

    def initialize(profile_revision_id:, profile:, qualities:)
      @profile_revision_id = profile_revision_id
      @profile = profile
      @qualities = qualities
      @contract = JSON.parse(File.read(File.join(__dir__, "implicit_quality_assessment.json")))
    end

    def call(client:)
      questions = build_questions
      response = @response = answer(client, questions) if questions.present?
      answers = response&.fetch("answers") || {}
      exchanges = questions.map { |id, question| { "id" => id, "question" => question, "result" => answers.fetch(id) } }

      {
        "profile_revision_id" => @profile_revision_id, "profile" => @profile,
        "calls" => exchanges.present? ? [ exchanges ] : [], "question_policy" => @contract,
        "applicable_quality_ids" => answers.filter_map do |id, result|
          id.to_i if result.fetch("noul") >= @contract.fetch("minimum_support")
        end,
        "configuration" => (client.configuration if response.present?),
        "model" => response&.fetch("model"), "usage" => response&.fetch("usage")
      }
    end

    private

    def build_questions
      return {} if @profile.blank?

      @qualities.keys.to_h do |quality_id|
        [ quality_id, {
          "type" => @contract.fetch("question_type"),
          "instructions" => @contract.fetch("question_template").gsub("{quality_id}", quality_id),
          "criteria" => @contract.fetch("criteria")
        } ]
      end
    end

    def answer(client, questions)
      state = { expression_profile: @profile, qualities: @qualities }
      phase = "assess-implicit-quality-evidence"
      @input = { "phase" => phase, "request" => { "model" => client.configuration.fetch("model"), "state" => state, "questions" => questions } }
      client.answer(state:, questions:, phase:)
    rescue TypeSafeClient::Error => error
      raise QualityAssessmentFailed.new(reason: error.reason), cause: nil
    end
  end
end
