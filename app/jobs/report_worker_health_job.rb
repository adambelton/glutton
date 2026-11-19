class ReportWorkerHealthJob < ApplicationJob
  queue_as :domain_events

  def perform
    return unless ActivityMonitoring.tracer

    now = Time.current
    cutoff = now - 30.minutes
    pending = {
      "job" => GoodJob::Job.unfinished.where(scheduled_at: ..cutoff).minimum(:scheduled_at),
      "profile_refresh" => Ratings::TasteProfileRefreshRequest.where(created_at: ..cutoff).minimum(:created_at),
      "reassessment" => Ratings::RatingQualityReassessmentRequest.where(created_at: ..cutoff).minimum(:created_at),
      "event_delivery" => DomainEvents::EventDelivery.due.where(next_attempt_at: ..cutoff).minimum(:next_attempt_at)
    }.compact
    if pending.empty?
      ActivityMonitoring.ignore_routine_activity
    else
      span = ActivityMonitoring.current
      span.set_attribute("glutton.overdue", true)
      pending.each { |kind, oldest| span.set_attribute("wait.#{kind}.seconds", (now - oldest).to_i) }
    end
  end
end
