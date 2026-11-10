module Ratings
  class Rating < ApplicationRecord
    module Values
      BRILLIANT = "brilliant".freeze
      PRETTY_GOOD = "pretty_good".freeze
      NOT_FOR_ME = "not_for_me".freeze
      GARBAGE = "garbage".freeze

      ALL = [ BRILLIANT, PRETTY_GOOD, NOT_FOR_ME, GARBAGE ].freeze
    end

    MAX_NOTES_LENGTH = 8_000

    belongs_to :rating_film
    has_many :rating_qualities
    has_many :rating_quality_evals

    scope :current, -> { where(id: Rating.group(:rating_film_id).select("MAX(id)")) }

    validates :notes, length: { maximum: MAX_NOTES_LENGTH }, allow_nil: true
    validate :recognized_value

    def can_assess_qualities_for?(profile_revision_id)
      !current_rating_quality_eval&.covers_profile_revision?(profile_revision_id)
    end

    def apply_quality_evaluation!(evaluation:)
      rating_film.with_lock(requires_new: true) do
        raise Errors::QualityAssessmentFailed.new(reason: :stale_rating) unless rating_film.ratings.maximum(:id) == id
        raise Errors::QualityApplicationUnavailable unless evaluation.persisted? && evaluation.rating == self
        next unless can_assess_qualities_for?(evaluation.profile_revision_id)

        ensure_explicit_evidence_current!(evaluation) if evaluation.profile_revision_id.present?
        apply_quality_scores!(evaluation)
        true
      end
    end

    def quality_evidence_for_reassessment
      current_rating_quality_eval&.explicit_evidence_for_reassessment
    end

    def request_profile_refresh_if_notes_changed!(previous_rating:)
      return if notes == previous_rating&.notes

      TasteProfileRefreshRequest.mark_pending!(user_id: rating_film.user_id)
    end

    def publish_event!
      DomainEvents::Publication::Publish.call(user_id: rating_film.user_id, publisher: Ratings::Events::PUBLISHING_DOMAIN,
        stream_key: "film:#{rating_film.film_id}", name: Ratings::Events::RATING_SUBMITTED, schema_version: 1,
        payload: { user_id: rating_film.user_id, film_id: rating_film.film_id, rating_id: id, value: })
    end

    private

    def ensure_explicit_evidence_current!(evaluation)
      applied = current_rating_quality_eval
      return if applied&.explicit_source_id == evaluation.inherited_explicit_evaluation_id

      raise Errors::QualityAssessmentFailed.new(reason: :explicit_evidence_changed)
    end

    def apply_quality_scores!(evaluation)
      evidence = evaluation.quality_evidence
      carried_scores = carried_explicit_scores(evaluation)
      evidence.fetch(:quality_ids).each do |quality_id|
        classification = classify_quality(quality_id, evidence)
        score = carried_scores.fetch(quality_id) { RatingQualityScores::ALL.fetch(classification).fetch(value) }
        rating_qualities.create!(rating_quality_eval: evaluation, quality_id:, classification:, score:)
      end
    end

    def carried_explicit_scores(evaluation)
      source_id = evaluation.inherited_explicit_evaluation_id
      return {} unless source_id.present?

      rating_qualities.where(rating_quality_eval_id: source_id,
        classification: RatingQuality::Classifications::EXPLICITLY_EXPRESSED).pluck(:quality_id, :score).to_h
    end

    def classify_quality(quality_id, evidence)
      if evidence.fetch(:explicit_ids).include?(quality_id)
        RatingQuality::Classifications::EXPLICITLY_EXPRESSED
      elsif evidence.fetch(:implicit_ids).include?(quality_id)
        RatingQuality::Classifications::IMPLICITLY_EXPRESSED
      else
        RatingQuality::Classifications::UNEXPRESSED
      end
    end

    def current_rating_quality_eval
      rating_quality_evals.joins(:rating_qualities).order(id: :desc).first
    end

    def recognized_value
      # External choices must match before Active Record's string coercion.
      errors.add(:value, :inclusion) unless Values::ALL.include?(value_before_type_cast)
    end
  end
end
