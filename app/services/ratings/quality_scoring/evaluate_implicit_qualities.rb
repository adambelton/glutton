module Ratings
  module QualityScoring
    class EvaluateImplicitQualities
      VERSIONS = %w[1].freeze
      CURRENT_VERSION = VERSIONS.last

      attr_reader :provider_calls, :result

      def initialize(profile_revision_id:, profile:, qualities:, rating_value:)
        @profile_revision_id, @profile, @qualities, @rating_value = profile_revision_id, profile, qualities, rating_value
        @contract = JSON.parse(File.read(File.join(__dir__, "evaluate_implicit_qualities_v#{CURRENT_VERSION}.json"))).merge("version" => CURRENT_VERSION)
      end

      def call(client:)
        questions = build_questions
        @provider_calls = []
        response = answer(client, questions) if questions.present?
        answers = response&.fetch("answers") || {}
        exchanges = questions.map { |id, question| { "id" => id, "question" => question, "result" => answers.fetch(id) } }

        @result = {
          "profile_revision_id" => @profile_revision_id, "profile" => @profile,
          "calls" => exchanges.present? ? [ exchanges ] : [], "question_policy" => @contract,
          "determinations" => determinations(answers),
          "configuration" => (client.configuration if response.present?),
          "model" => response&.fetch("model"), "usage" => response&.fetch("usage")
        }
        self
      end

      private

      def build_questions
        return {} if @profile.blank?

        film_reaction = RatingQualityScores.film_reaction(@rating_value)
        @qualities.keys.each_with_object({}) do |quality_id, questions|
          @contract.fetch("questions").each do |judgment, question|
            questions["quality_#{quality_id}_#{judgment}"] = question.merge("instructions" => question.fetch("instructions")
              .gsub("{quality_id}", quality_id).gsub("{film_reaction}", film_reaction))
          end
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

      def determinations(answers)
        return {} if answers.empty?

        @qualities.keys.filter_map do |quality_id|
          probabilities = @contract.fetch("questions").keys.index_with do |judgment|
            answers.fetch("quality_#{quality_id}_#{judgment}").fetch("noul")
          end
          determination = InterpretQualityEvidence.call(probabilities:, policy: @contract, positive: false)
          [ quality_id, determination ] if determination.present?
        end.to_h
      end
    end
  end
end
