module Ratings
  class RatingQualityEval < ApplicationRecord
    belongs_to :rating
    has_many :rating_qualities
    attr_readonly :rating_id, :input, :output

    validate :evaluation_output

    def self.record!(rating:, assessment:)
      create!(rating:, input: assessment.input, output: assessment.result)
    end

    def quality_evidence
      decisions = output.fetch("decisions")
      quality_ids = output.fetch("qualities").keys.map(&:to_i)
      direct = decisions.to_h { |decision| decision.values_at("quality_id", "determination") }
      unless direct.size == decisions.size && direct.keys.sort == quality_ids.sort
        raise Errors::QualityApplicationUnavailable
      end

      inferred = output.dig("implicit_assessment", "determinations") || {}
      { quality_ids:, direct:, inferred: inferred.transform_keys(&:to_i) }
    end

    def profile_revision_id
      output.dig("implicit_assessment", "profile_revision_id")
    end

    def covers_profile_revision?(revision_id)
      applied_revision_id = profile_revision_id
      revision_id.nil? || (applied_revision_id.present? && applied_revision_id >= revision_id)
    end

    def inherited_explicit_evaluation_id
      output["explicit_source_evaluation_id"]
    end

    def explicit_evidence_for_reassessment
      return unless output.dig("question_policy", "questions").present?

      output.slice("notes", "qualities", "calls", "decisions", "question_policy", "minimum_support",
        "configuration", "model", "usage").merge("explicit_source_evaluation_id" => inherited_explicit_evaluation_id || id)
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

      notes, qualities, calls, decisions = output.values_at("notes", "qualities", "calls", "decisions")
      return false unless valid_notes?(notes) && valid_qualities?(qualities)
      return false unless decisions.is_a?(Array) && decisions.present?

      direct = QualityScoring::InterpretQualityEvidence::PREFERENCE_QUESTIONS + QualityScoring::InterpretQualityEvidence::EXECUTION_QUESTIONS
      probabilities = probabilities_by_id(calls)
      return false unless probabilities

      policy = output["question_policy"]
      expected_ids = notes.present? ? qualities.keys.flat_map { |id| direct.map { |judgment| "notes_#{rating.id}_quality_#{id}_#{judgment}" } } : []
      return false unless probabilities.keys.sort == expected_ids.sort
      return false if notes.present? && !valid_policy?(policy, direct)

      decisions.all? { |decision| valid_decision?(decision, notes, qualities, probabilities, direct, policy) } &&
        valid_implicit_assessment?(qualities, decisions)
    end

    def valid_implicit_assessment?(qualities, decisions)
      return true unless output.key?("implicit_assessment")

      implicit = output["implicit_assessment"]
      return false unless implicit.is_a?(Hash)

      revision_id, profile, calls, determinations, policy = implicit.values_at(
        "profile_revision_id", "profile", "calls", "determinations", "question_policy")
      return false unless revision_id.is_a?(Integer) && profile.is_a?(String) && determinations.is_a?(Hash)
      return false unless TasteProfileRevision.joins(:taste_profile)
        .exists?(id: revision_id, profile:, taste_profiles: { user_id: rating.rating_film.user_id })

      direct_ids = decisions.filter_map { |decision| decision.fetch("quality_id").to_s if decision["determination"].present? }
      eligible_ids = profile.present? ? qualities.keys - direct_ids : []
      judgments = QualityScoring::InterpretQualityEvidence::PREFERENCE_QUESTIONS
      return calls == [] && determinations.empty? if eligible_ids.empty?

      probabilities = probabilities_by_id(calls)
      expected_ids = eligible_ids.flat_map { |id| judgments.map { |judgment| "quality_#{id}_#{judgment}" } }
      return false unless probabilities && probabilities.keys.sort == expected_ids.sort && valid_policy?(policy, judgments)

      determinations == eligible_ids.filter_map do |id|
        answers = judgments.index_with { |judgment| probabilities.fetch("quality_#{id}_#{judgment}") }
        determination = QualityScoring::InterpretQualityEvidence.call(probabilities: answers, policy:, positive: false)
        [ id, determination ] if determination.present?
      end.to_h
    end

    def probabilities_by_id(calls)
      return unless calls.is_a?(Array) && calls.all? { |call| call.is_a?(Array) && call.present? }

      exchanges = calls.flatten(1)
      return unless exchanges.all? do |exchange|
        next false unless exchange.is_a?(Hash) && exchange["id"].is_a?(String) && exchange["question"].present?

        result = exchange["result"]
        result.is_a?(Hash) && result["noul"].is_a?(Numeric) && result["noul"].between?(0, 1)
      end

      probabilities = exchanges.to_h { |exchange| [ exchange.fetch("id"), exchange.fetch("result").fetch("noul") ] }
      probabilities if probabilities.size == exchanges.size
    end

    def valid_policy?(policy, judgments)
      return false unless policy.is_a?(Hash) && policy["questions"].is_a?(Hash) && policy["questions"].keys.sort == judgments.sort

      high, competing = policy.values_at("minimum_support", "competing_support")
      high.is_a?(Numeric) && competing.is_a?(Numeric) && competing.between?(0, high) && high <= 1
    end

    def valid_notes?(notes)
      expected = rating.notes.present? ? { rating.id.to_s => rating.notes } : {}
      notes == expected
    end

    def valid_qualities?(qualities)
      qualities.is_a?(Hash) && qualities.present? && qualities.all? do |id, definition|
        id.match?(/\A[1-9]\d*\z/) && definition.is_a?(Hash) && definition["name"].is_a?(String) &&
          definition["name"].present? && definition.key?("match_rule") && definition.key?("not_sufficient")
      end
    end

    def valid_decision?(decision, notes, qualities, probabilities, judgments, policy)
      return false unless decision.is_a?(Hash) && decision.key?("determination")

      quality_id, determination, supporting_ids, result_ids = decision.values_at(
        "quality_id", "determination", "supporting_rating_ids", "result_ids")
      return false unless quality_id.is_a?(Integer) && qualities.key?(quality_id.to_s)
      return determination.nil? && supporting_ids == [] && result_ids == [] if notes.empty?

      ids = judgments.index_with { |judgment| "notes_#{rating.id}_quality_#{quality_id}_#{judgment}" }
      return false unless result_ids.is_a?(Array) && result_ids.sort == ids.values.sort

      answers = ids.transform_values { |id| probabilities.fetch(id) }
      expected = QualityScoring::InterpretQualityEvidence.call(probabilities: answers, policy:,
        positive: RatingQualityScores::UNEXPRESSED.fetch(rating.value).positive?)
      determination == expected && supporting_ids == (expected.present? ? [ rating.id ] : [])
    end
  end
end
