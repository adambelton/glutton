module Ratings
  module QualityScoring
    class ScoreRatingQualities
      TRACE_NAME = "assess-rating-qualities".freeze
      TRACE_TAGS = [ "ratings", "quality-assessment" ].freeze

      def self.call(rating_id:, client: nil, tracer_provider: ActivityMonitoring.ai_tracer_provider)
        new(rating_id:, client:, tracer_provider:).call
      end

      def initialize(rating_id:, client:, tracer_provider:)
        @rating_id = rating_id
        @tracer_provider = tracer_provider
        @client = client || TypeSafeClient.new(tracer: ActivityMonitoring.ai_tracer(ActivityMonitoring::Scopes::RATINGS, provider: tracer_provider), profile: :ratings)
      end

      def call
        rating = Rating.find(@rating_id)
        rating_film = rating.rating_film
        ensure_current!(rating_film, rating)
        profile_revision = TasteProfile.find_by(user_id: rating_film.user_id)&.current_revision
        unless rating.can_assess_qualities_for?(profile_revision&.id)
          ActivityMonitoring.current_operation_span&.set_outcome(ActivityMonitoring::AssessmentOutcomes::ALREADY_ASSESSED)
          return
        end

        explicit_evidence = rating.quality_evidence_for_reassessment
        qualities = explicit_evidence&.fetch("qualities") || capture_qualities(rating_film)
        if qualities.empty?
          ActivityMonitoring.current_operation_span&.set_outcome(ActivityMonitoring::AssessmentOutcomes::NO_QUALITIES)
          return
        end

        notes = rating.notes.present? ? { rating.id.to_s => rating.notes } : {}
        ActivityMonitoring.trace_ai_workflow(TRACE_NAME, scope: ActivityMonitoring::Scopes::RATINGS, provider: @tracer_provider, tags: TRACE_TAGS,
          input: { rating_id: rating.id, notes_count: notes.size, quality_count: qualities.size }) do |span|
          trace_id = span.trace_id
          evaluation = assess_and_record(rating:, notes:, qualities:, profile_revision:, trace_id:, explicit_evidence:)
          outcome = evaluation.present? ? ActivityMonitoring::AssessmentOutcomes::ASSESSED : ActivityMonitoring::AssessmentOutcomes::SUPERSEDED
          ActivityMonitoring.current_operation_span&.set_outcome(outcome)
          span.set_attribute("rating_quality_eval_id", evaluation.id) if evaluation.present?
          evaluation
        end
      end

      private

      def capture_qualities(rating_film)
        rating_film.film.qualities.order(:id).to_h do |quality|
          [ quality.id.to_s, { "name" => quality.name, "match_rule" => quality.match_rule, "not_sufficient" => quality.not_sufficient } ]
        end
      end

      def assess_and_record(rating:, notes:, qualities:, profile_revision:, trace_id:, explicit_evidence:)
        assessment = EvaluateRatingQualities.new(notes:, qualities:, rating_value: rating.value, profile_revision_id: profile_revision&.id,
          profile: profile_revision&.profile, trace_id:, explicit_evidence:).call(client: @client)
        record_and_apply(rating:, assessment:)
      rescue Errors::QualityAssessmentFailed => error
        raise unless error.reason == :explicit_evidence_changed
        return unless rating.can_assess_qualities_for?(profile_revision.id)

        explicit_evidence = rating.quality_evidence_for_reassessment
        assessment = EvaluateRatingQualities.new(notes:, qualities:, rating_value: rating.value, profile_revision_id: profile_revision.id,
          profile: profile_revision.profile, trace_id:, explicit_evidence:, previous_assessment: assessment).call(client: @client)
        record_and_apply(rating:, assessment:)
      end

      def record_and_apply(rating:, assessment:)
        Rating.transaction(requires_new: true) do
          evaluation = RatingQualityEval.record!(rating:, assessment:)
          raise ActiveRecord::Rollback unless rating.apply_quality_evaluation!(evaluation:)

          evaluation
        end
      end

      def ensure_current!(rating_film, rating)
        raise Errors::QualityAssessmentFailed.new(reason: :stale_rating) unless rating_film.ratings.maximum(:id) == rating.id
      end
    end
  end
end
