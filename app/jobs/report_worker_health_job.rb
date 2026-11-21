class ReportWorkerHealthJob < ApplicationJob
  OVERDUE_AFTER = 30.minutes.freeze

  queue_as :domain_events

  def perform
    return unless ActivityMonitoring.operation_tracer

    now = Time.current
    cutoff = now - OVERDUE_AFTER
    pending = {
      "job" => GoodJob::Job.unfinished.where(scheduled_at: ..cutoff).minimum(:scheduled_at),
      "profile_refresh" => Ratings::TasteProfileRefreshRequest.where(created_at: ..cutoff).minimum(:created_at),
      "reassessment" => Ratings::RatingQualityReassessmentRequest.where(created_at: ..cutoff).minimum(:created_at),
      "event_delivery" => DomainEvents::EventDelivery.due.where(next_attempt_at: ..cutoff).minimum(:next_attempt_at)
    }.compact
    span = ActivityMonitoring.current_operation_span
    span.set_outcome(pending.empty? ? "healthy" : "overdue")
    pending.each { |kind, oldest| span.set_overdue_wait(kind, (now - oldest).to_i) }
  end
end
