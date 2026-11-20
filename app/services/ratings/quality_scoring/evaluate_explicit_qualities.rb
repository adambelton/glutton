module Ratings
  module QualityScoring
    class EvaluateExplicitQualities
      VERSIONS = %w[1].freeze
      CURRENT_VERSION = VERSIONS.last

      attr_reader :provider_calls, :result

      def initialize(notes:, qualities:, rating_value:, trace_id:)
        @notes, @qualities, @rating_value, @trace_id = notes, qualities, rating_value, trace_id
        @contract = JSON.parse(File.read(File.join(__dir__, "evaluate_explicit_qualities_v#{CURRENT_VERSION}.json"))).merge("version" => CURRENT_VERSION)
      end

      def call(client:)
        questions = build_questions
        configuration = client.configuration if questions.present?
        @provider_calls = []
        response = answer(client, questions, configuration) if questions.present?
        answers = response&.fetch("answers") || {}
        exchanges = questions.map { |id, question| { "id" => id, "question" => question, "result" => answers.fetch(id) } }
        @result = {
          "notes" => @notes, "qualities" => @qualities, "calls" => exchanges.present? ? [ exchanges ] : [],
          "decisions" => decisions(answers), "question_policy" => @contract,
          "minimum_support" => @contract.fetch("minimum_support"),
          "configuration" => { "maximum_pairs" => @contract.fetch("maximum_pairs"), "provider" => configuration },
          "model" => response&.fetch("model"), "usage" => response&.fetch("usage"), "trace_id" => @trace_id
        }
        self
      end

      private

      def build_questions
        if @notes.size * @qualities.size > @contract.fetch("maximum_pairs")
          raise Errors::QualityAssessmentFailed.new(reason: :too_large)
        end

        film_reaction = RatingQualityScores.film_reaction(@rating_value)
        @notes.keys.product(@qualities.keys).each_with_object({}) do |(rating_id, quality_id), questions|
          @contract.fetch("questions").each do |judgment, question|
            id = "notes_#{rating_id}_quality_#{quality_id}_#{judgment}"
            questions[id] = question.merge("instructions" => question.fetch("instructions")
              .gsub("{rating_id}", rating_id).gsub("{quality_id}", quality_id).gsub("{film_reaction}", film_reaction))
          end
        end
      end

      def answer(client, questions, configuration)
        phase = "assess-explicit-quality-evidence"
        state = { notes: @notes, qualities: @qualities }
        request = { "model" => configuration.fetch("model"), "state" => state, "questions" => questions }
        response = client.answer(state:, questions:, phase:)
        @provider_calls << { "phase" => phase, "request" => request, "response" => response }
        response
      rescue TypeSafeClient::Error => error
        raise Errors::QualityAssessmentFailed.new(reason: error.reason), cause: nil
      end

      def decisions(answers)
        @qualities.keys.map do |quality_id|
          rating_id = @notes.keys.first
          ids = @contract.fetch("questions").keys.index_with { |judgment| "notes_#{rating_id}_quality_#{quality_id}_#{judgment}" } if rating_id.present?
          probabilities = ids&.transform_values { |id| answers.fetch(id).fetch("noul") } || {}
          determination = InterpretQualityEvidence.call(probabilities:, policy: @contract,
            positive: RatingQualityScores::UNEXPRESSED.fetch(@rating_value).positive?)
          { "quality_id" => quality_id.to_i, "determination" => determination,
            "supporting_rating_ids" => determination.present? ? [ rating_id.to_i ] : [], "result_ids" => ids&.values || [] }
        end
      end
    end
  end
end
