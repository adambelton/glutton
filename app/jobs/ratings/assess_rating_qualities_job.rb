module Ratings
  class AssessRatingQualitiesJob < ApplicationJob
    include GoodJob::ActiveJobExtensions::Concurrency
    include GoodJob::ActiveJobExtensions::InterruptErrors

    queue_as :ratings_assessment
    self.enqueue_after_transaction_commit = false

    good_job_concurrency_rule perform_limit: 1, apply_label: true,
      label: -> { "ratings-assessment:#{arguments.first}" }

    def self.enqueue!(rating_id)
      perform_later(rating_id) || raise(ActiveJob::EnqueueError, "Could not enqueue Ratings quality assessment")
    end

    def perform(rating_id)
      QualityScoring::ScoreRatingQualities.call(rating_id:)
    rescue Errors::QualityAssessmentFailed => error
      raise unless error.reason == :stale_rating
    rescue ActiveRecord::RecordNotFound
      raise if Rating.exists?(rating_id)
    end
  end
end
