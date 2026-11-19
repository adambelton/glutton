class ReportWorkerHealthJob < ApplicationJob
  queue_as :domain_events

  def perform
    return unless defined?(Appsignal) && Appsignal.active?

    Appsignal::CheckIn.heartbeat("goodjob_worker")
  end
end
