module Ratings
  class RatingQualityEval < ApplicationRecord
    belongs_to :rating
    attr_readonly :rating_id, :output

    validate :evaluation_output

    def self.record!(rating:, assessment:)
      create!(rating:, output: assessment.result)
    end

    def readonly?
      super || persisted?
    end

    private

    def evaluation_output
      errors.add(:output, :invalid) unless valid_output?
    end

    def valid_output?
      return false unless output.is_a?(Hash) && rating.present?

      expressions, qualities, calls, decisions = output.values_at("expressions", "qualities", "calls", "decisions")
      return false unless valid_expressions?(expressions) && valid_qualities?(qualities)
      return false unless decisions.is_a?(Array) && decisions.present?

      question_ids = assessment_question_ids(calls)
      return false unless question_ids

      decisions.all? { |decision| valid_decision?(decision, expressions, qualities, question_ids) }
    end

    def assessment_question_ids(calls)
      return unless calls.is_a?(Array) && calls.present? && calls.all? { |call| call.is_a?(Array) && call.present? }

      exchanges = calls.flatten(1)
      return unless exchanges.all? { |exchange| valid_exchange?(exchange) }

      question_ids = exchanges.pluck("id")
      question_ids if question_ids.uniq.size == question_ids.size
    end

    def valid_exchange?(exchange)
      exchange.is_a?(Hash) && exchange["id"].is_a?(String) && exchange["id"].present? &&
        exchange["question"].present? && exchange.key?("result")
    end

    def valid_expressions?(expressions)
      return false unless expressions.is_a?(Hash) && expressions.present?

      original_texts = rating.rating_expressions.pluck(:id, :text).to_h.transform_keys(&:to_s)
      expressions.all? { |id, text| original_texts.key?(id) && original_texts.fetch(id) == text }
    end

    def valid_qualities?(qualities)
      qualities.is_a?(Hash) && qualities.present? && qualities.all? do |id, definition|
        id.match?(/\A[1-9]\d*\z/) && definition.is_a?(Hash) && definition["name"].is_a?(String) &&
          definition["name"].present? && definition.key?("match_rule") && definition.key?("not_sufficient")
      end
    end

    def valid_decision?(decision, expressions, qualities, question_ids)
      return false unless decision.is_a?(Hash)

      quality_id, applicable, supporting_ids, result_ids = decision.values_at(
        "quality_id", "applicable", "supporting_expression_ids", "result_ids")
      qualities.key?(quality_id.to_s) && [ true, false ].include?(applicable) &&
        supporting_ids.is_a?(Array) && applicable == supporting_ids.present? &&
        supporting_ids.all? { |id| expressions.key?(id.to_s) } &&
        result_ids.is_a?(Array) && result_ids.present? && (result_ids - question_ids).empty?
    end
  end
end
