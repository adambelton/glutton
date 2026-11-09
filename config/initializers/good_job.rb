Rails.application.configure do
  config.good_job.execution_mode = :external
  config.good_job.threads = 2
  config.good_job.poll_interval = 30
  config.good_job.enable_listen_notify = true
  config.good_job.enable_cron = !Rails.env.test?
  config.good_job.cron = {
    domain_event_sweep: {
      cron: "*/30 * * * * *",
      class: "DispatchDomainEventsJob"
    },
    ratings_expression_profile_refresh: {
      cron: "*/15 * * * * UTC",
      class: "Ratings::RefreshExpressionProfilesJob",
      enabled_by_default: -> { Rails.env.production? }
    }
  }
  config.good_job.preserve_job_records = true
  config.good_job.cleanup_preserved_jobs_before_seconds_ago = 7.days.to_i
end
