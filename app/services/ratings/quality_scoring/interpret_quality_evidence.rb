module Ratings
  module QualityScoring
    class InterpretQualityEvidence
      PREFERENCE_QUESTIONS = %w[reinforces ruled_out exception].freeze
      EXECUTION_QUESTIONS = %w[praises_execution criticises_execution].freeze

      def self.call(probabilities:, policy:, positive:)
        preference = probabilities.slice(*PREFERENCE_QUESTIONS)
        judgment = supported_judgment(preference, policy)
        return judgment if judgment.present?
        return if preference.values.any? { |probability| probability >= policy.fetch("minimum_support") }

        execution = supported_judgment(probabilities.slice(*EXECUTION_QUESTIONS), policy)
        execution if execution == "criticises_execution" || (execution == "praises_execution" && positive)
      end

      def self.supported_judgment(probabilities, policy)
        judgments = probabilities.select { |_, probability| probability >= policy.fetch("competing_support") }
        return unless judgments.size == 1

        judgment, probability = judgments.first
        judgment if probability >= policy.fetch("minimum_support")
      end
      private_class_method :supported_judgment
    end
  end
end
