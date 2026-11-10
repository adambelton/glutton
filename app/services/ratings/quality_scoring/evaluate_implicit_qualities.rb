module Ratings
  module QualityScoring
    class EvaluateImplicitQualities
      attr_reader :provider_calls

      def initialize(profile_revision_id:, profile:, qualities:)
        @profile_revision_id = profile_revision_id
        @profile = profile
        @qualities = qualities
        @contract = JSON.parse(File.read(File.join(__dir__, "evaluate_implicit_qualities.json")))
      end

      def call(client:)
        questions = build_questions
        @provider_calls = []
        response = answer(client, questions) if questions.present?
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
        state = { taste_profile: @profile, qualities: @qualities }
        phase = "assess-implicit-quality-evidence"
        request = { "model" => client.configuration.fetch("model"), "state" => state, "questions" => questions }
        response = client.answer(state:, questions:, phase:)
        @provider_calls << { "phase" => phase, "request" => request, "response" => response }
        response
      rescue TypeSafeClient::Error => error
        raise Errors::QualityAssessmentFailed.new(reason: error.reason), cause: nil
      end
    end
  end
end
