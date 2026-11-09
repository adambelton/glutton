module Ratings
  class RatingQualityEval < ApplicationRecord
    belongs_to :rating
    has_many :rating_qualities
    attr_readonly :rating_id, :output

    validate :evaluation_output

    def self.record!(rating:, assessment:)
      output = assessment.result
      scores = RatingQualityScores::ALL
      if output.key?("explicit_source_evaluation_id")
        source = rating.rating_quality_evals.find(output.fetch("explicit_source_evaluation_id"))
        explicit = RatingQuality::Classifications::EXPLICITLY_EXPRESSED
        weights = source.output["score_weights"] || source.output.dig("question_policy", "scores") || scores
        scores = scores.merge(explicit => weights.fetch(explicit))
        carried_scores = source.rating_qualities.where(classification: explicit).pluck(:quality_id, :score).to_h.transform_keys(&:to_s)
        output = output.merge("carried_explicit_scores" => carried_scores)
      end
      evaluation = new(rating:, output: output.merge("score_weights" => scores))
      rating_film = rating.rating_film
      rating_film.with_lock(requires_new: true) do
        raise QualityAssessmentFailed.new(reason: :stale_rating) unless rating_film.ratings.maximum(:id) == rating.id
        next unless rating.can_apply_quality_evaluation?(evaluation)

        rating.ensure_explicit_evidence_current!(evaluation) if evaluation.profile_revision_id.present?
        evaluation.save!
        apply_quality_scores!(evaluation)
        evaluation
      end
    end

    def profile_revision_id
      output.dig("implicit_assessment", "profile_revision_id")
    end

    def covers_profile_revision?(revision_id)
      applied_revision_id = profile_revision_id
      revision_id.nil? || (applied_revision_id.present? && applied_revision_id >= revision_id)
    end

    def explicit_source_id
      output["explicit_source_evaluation_id"] || id
    end

    def explicit_evidence_for_reassessment
      output.slice("expressions", "qualities", "calls", "decisions", "question_policy", "minimum_support",
        "configuration", "model", "usage").merge("explicit_source_evaluation_id" => explicit_source_id)
    end

    def readonly?
      super || persisted?
    end

    def self.apply_quality_scores!(evaluation)
      output = evaluation.output
      rating = evaluation.rating
      decisions = output.fetch("decisions")
      unless decisions.map { |decision| decision.fetch("quality_id").to_s }.uniq.size == decisions.size
        raise QualityApplicationUnavailable
      end

      explicit_ids = decisions.select { |decision| decision.fetch("applicable") }.pluck("quality_id").map(&:to_i)
      implicit_ids = output.dig("implicit_assessment", "applicable_quality_ids") || []
      scores = output.fetch("score_weights")
      carried_scores = output["carried_explicit_scores"] || {}
      output.fetch("qualities").keys.map(&:to_i).each do |quality_id|
        classification = classify_quality(quality_id, explicit_ids, implicit_ids)
        score = carried_scores.fetch(quality_id.to_s) { scores.fetch(classification).fetch(rating.value) }
        evaluation.rating_qualities.create!(rating:, quality_id:, classification:, score:)
      end
    end

    def self.classify_quality(quality_id, explicit_ids, implicit_ids)
      if explicit_ids.include?(quality_id)
        RatingQuality::Classifications::EXPLICITLY_EXPRESSED
      elsif implicit_ids.include?(quality_id)
        RatingQuality::Classifications::IMPLICITLY_EXPRESSED
      else
        RatingQuality::Classifications::UNEXPRESSED
      end
    end
    private_class_method :apply_quality_scores!, :classify_quality

    private

    def evaluation_output
      errors.add(:output, :invalid) unless valid_output?
    end

    def valid_output?
      return false unless output.is_a?(Hash) && rating.present?

      expressions, qualities, calls, decisions = output.values_at("expressions", "qualities", "calls", "decisions")
      return false unless valid_expressions?(expressions) && valid_qualities?(qualities)
      return false unless decisions.is_a?(Array) && decisions.present?

      return false unless valid_implicit_assessment?(qualities, decisions)

      if expressions.empty?
        return calls == [] && decisions.all? do |decision|
          valid_decision?(decision, expressions, qualities, [])
        end
      end

      question_ids = assessment_question_ids(calls)
      return false unless question_ids

      decisions.all? { |decision| valid_decision?(decision, expressions, qualities, question_ids) }
    end

    def valid_implicit_assessment?(qualities, decisions)
      return true unless output.key?("implicit_assessment")

      implicit = output["implicit_assessment"]
      return false unless implicit.is_a?(Hash)

      revision_id, profile, calls, applicable_ids = implicit.values_at(
        "profile_revision_id", "profile", "calls", "applicable_quality_ids")
      return false unless revision_id.is_a?(Integer) && profile.is_a?(String) && applicable_ids.is_a?(Array)
      return false unless ExpressionProfileRevision.joins(:expression_profile)
        .exists?(id: revision_id, profile:, expression_profiles: { user_id: rating.rating_film.user_id })
      return false unless decisions.all? { |decision| decision.is_a?(Hash) }

      explicit_ids = decisions.select { |decision| decision["applicable"] }.pluck("quality_id").map(&:to_s)
      eligible_ids = qualities.keys - explicit_ids
      return calls == [] && applicable_ids.empty? if profile.blank? || eligible_ids.empty?
      return false unless calls.is_a?(Array) && calls.size == 1
      return false unless assessment_question_ids(calls)&.sort == eligible_ids.sort

      threshold = implicit.dig("question_policy", "minimum_support") if implicit["question_policy"].is_a?(Hash)
      return false unless threshold.is_a?(Numeric) && threshold.between?(0, 1)

      exchanges = calls.first
      return false unless exchanges.all? do |exchange|
        result = exchange["result"]
        result.is_a?(Hash) && result["noul"].is_a?(Numeric) && result["noul"].between?(0, 1)
      end

      applicable_ids == exchanges.filter_map do |exchange|
        exchange.fetch("id").to_i if exchange.fetch("result").fetch("noul") >= threshold
      end
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
