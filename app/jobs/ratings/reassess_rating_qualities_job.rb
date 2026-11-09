module Ratings
  class ReassessRatingQualitiesJob < ApplicationJob
    include GoodJob::ActiveJobExtensions::Concurrency
    include GoodJob::ActiveJobExtensions::InterruptErrors

    queue_as :ratings_assessment
    self.enqueue_after_transaction_commit = false

    good_job_concurrency_rule perform_limit: 1, apply_label: true,
      label: -> { "ratings-reassessment:#{arguments.first}" }

    def self.enqueue!(user_id:, profile_revision_id:)
      perform_later(user_id, profile_revision_id) || raise(ActiveJob::EnqueueError, "Could not enqueue Ratings reassessment")
    end

    def perform(user_id, profile_revision_id)
      request = RatingQualityReassessmentRequest.find_by(user_id:, expression_profile_revision_id: profile_revision_id)
      return unless request.present?

      if request.user.active?
        Rating.current.joins(:rating_film).where(rating_films: { user_id: }).find_each do |rating|
          break unless request.pending?

          reassess(rating)
        end
      end
      request.acknowledge!
    end

    private

    def reassess(rating)
      AssessRatingQualities.call(rating_id: rating.id)
    rescue QualityAssessmentFailed => error
      raise unless error.reason == :stale_rating
    rescue ActiveRecord::RecordNotFound
      raise if Rating.exists?(rating.id)
    end
  end
end
