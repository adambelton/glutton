module Ratings
  class RatingQualityEval < ApplicationRecord
    belongs_to :rating
    has_many :rating_qualities
    attr_readonly :rating_id, :output

    validate :evaluation_output

    def self.record!(rating:, assessment:)
      create!(rating:, output: assessment.result.merge("score_weights" => RatingQualityScores::ALL))
    end

    def readonly?
      super || persisted?
    end

    def apply_quality_scores!
      quality_ids = output.fetch("qualities").keys.map(&:to_i)
      decisions = output.fetch("decisions")
      unless decisions.map { |decision| decision.fetch("quality_id").to_s }.uniq.size == decisions.size
        raise QualityApplicationUnavailable
      end
      raise QualityApplicationUnavailable if rating_qualities.exists?

      explicit_ids = decisions.select { |decision| decision.fetch("applicable") }.pluck("quality_id").map(&:to_i)
      scores = output["score_weights"] || output.dig("question_policy", "scores") || RatingQualityScores::ALL
      transaction(requires_new: true) do
        quality_ids.map do |quality_id|
          classification = classify_quality(quality_id, explicit_ids)
          score = scores.fetch(classification).fetch(rating.value)
          rating_qualities.create!(rating:, quality_id:, classification:, score:)
        end
      end
    end

    private

    def classify_quality(quality_id, explicit_ids)
      if explicit_ids.include?(quality_id)
        RatingQuality::Classifications::EXPLICITLY_EXPRESSED
      else
        RatingQuality::Classifications::UNEXPRESSED
      end
    end

    def evaluation_output
      errors.add(:output, :invalid) unless valid_output?
    end

    def valid_output?
      return false unless output.is_a?(Hash) && rating.present?

      expressions, qualities, calls, decisions = output.values_at("expressions", "qualities", "calls", "decisions")
      return false unless valid_expressions?(expressions) && valid_qualities?(qualities)
      return false unless decisions.is_a?(Array) && decisions.present?

      if expressions.empty?
        return calls == [] && decisions.all? do |decision|
          valid_decision?(decision, expressions, qualities, [])
        end
      end

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
      return false unless expressions.is_a?(Hash)

      original_texts = rating.rating_expressions.pluck(:id, :text).to_h.transform_keys(&:to_s)
      return original_texts.empty? if expressions.empty?

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
        result_ids.is_a?(Array) && (expressions.empty? ? result_ids.empty? : result_ids.present?) &&
        (result_ids - question_ids).empty?
    end
  end
end
