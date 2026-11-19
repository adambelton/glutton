module Ratings
  class RefreshTasteProfilesJob < ApplicationJob
    include GoodJob::ActiveJobExtensions::Concurrency

    queue_as :ratings_assessment
    good_job_concurrency_rule total_limit: 1, apply_label: true,
      label: -> { arguments.empty? ? "ratings-profile-refresh-scheduled" : "ratings-profile-refresh-user-#{arguments.first}" }
    good_job_concurrency_rule perform_limit: 1, apply_label: true, label: "ratings-profile-refresh"

    def perform(user_id = nil)
      if user_id.present?
        user = Identity::User.find_by(id: user_id)
        return unless user&.active? && user.superuser?
      end

      failures = TasteProfiling::ProcessProfileRefreshes.call(user_id:).fetch(:failures)
      if failures.present?
        Rails.logger.warn("Ratings taste profile refresh failures: #{failures.values.tally}")
      end
    end
  end
end
