module Ratings
  class ExpressionProfileRevisionEval < ApplicationRecord
    belongs_to :expression_profile
    attr_readonly :expression_profile_id, :input, :output

    validate :evaluation_output

    def self.record!(expression_profile:, assessment:)
      create!(expression_profile:, input: assessment.input, output: assessment.result)
    end

    def readonly?
      super || persisted?
    end

    def revision_attributes
      {
        profile: output.fetch("profile"),
        annotations: output.fetch("annotations", []),
        expression_texts: output.fetch("evidence").map { |expression| expression.slice("film_id", "text") }
      }
    end

    private

    def evaluation_output
      errors.add(:output, :invalid) unless valid_output?
    end

    def valid_output?
      return false unless output.is_a?(Hash) && %w[evidence profile synthesis trace_id].all? { |key| output.key?(key) }

      evidence, profile, synthesis = output.values_at("evidence", "profile", "synthesis")
      return false unless evidence.is_a?(Array) && evidence.all? { |expression| valid_expression?(expression) }

      if evidence.empty?
        profile == "" && synthesis.nil?
      else
        profile.is_a?(String) && profile.present? && valid_synthesis?(synthesis)
      end
    end

    def valid_expression?(expression)
      expression.is_a?(Hash) &&
        expression.values_at("expression_id", "rating_id", "film_id").all? { |id| id.is_a?(Integer) && id.positive? } &&
        expression["film_title"].is_a?(String) && expression["text"].is_a?(String) && expression["text"].present? &&
        expression.key?("film_release_date")
    end

    def valid_synthesis?(synthesis)
      return false unless synthesis.is_a?(Hash)

      provider, model, usage = synthesis.values_at("provider", "model", "usage")
      [ provider, model ].all? { |text| text.is_a?(String) && text.present? } &&
        usage.is_a?(Hash) && usage.values_at("input", "output").all? { |count| count.is_a?(Integer) && count >= 0 }
    end
  end
end
