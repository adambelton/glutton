require "test_helper"
require_relative "../support/assessed_recommendation_films"

class ActivityMonitoringTest < ActionDispatch::IntegrationTest
  include AssessedRecommendationFilms

  setup do
    @exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    @provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    @provider.add_span_processor(ActivityMonitoring::Processor.new(@exporter))
    @original = ActivityMonitoring.tracer
    ActivityMonitoring.tracer = @provider.tracer(ActivityMonitoring::TRACER_NAME)
  end

  teardown do
    ActivityMonitoring.tracer = @original
    @provider.shutdown
  end

  test "web actions and worker hooks capture business activity without successful polling or idle scheduling" do
    get root_path
    post guest_session_path
    get availability_recommendation_path
    assert_response :accepted
    unlock_recommendations_for(user: Identity::UserGuest.last)
    film = Registry::Film.create!(title: "Candidate")
    get recommendation_path
    get recommendation_path
    2.times { get new_rating_path(film_id: film.id) }
    @provider.force_flush
    spans = @exporter.finished_spans
    assert_equal [ "GuestSessionsController#create", "RecommendationsController#show", "RatingsController#new" ], spans.map(&:name)
    assert_equal [ "rank recommendation films", "create rating film" ], spans.filter_map { |span| span.attributes[ActivityMonitoring::OPERATION] }
  end

  test "scheduled jobs suppress successful idle runs and enqueues while retaining failures" do
    tracer = @provider.tracer(ActivityMonitoring::ACTIVE_JOB_SCOPE)
    [ DispatchDomainEventsJob, Ratings::RefreshTasteProfilesJob, ReportWorkerHealthJob ].each do |job|
      attributes = { OpenTelemetry::SemConv::Incubating::CODE::CODE_NAMESPACE => job.name }
      tracer.in_span("enqueue #{job.name}", kind: :producer, attributes:) { }
      tracer.in_span("perform #{job.name}", kind: :consumer, attributes:) { job.perform_now }
    end
    job_attribute = OpenTelemetry::SemConv::Incubating::CODE::CODE_NAMESPACE
    user = Identity::UserGuest.create!
    Ratings::TasteProfileRefreshRequest.mark_pending!(user_id: user.id)
    travel ReportWorkerHealthJob::OVERDUE_AFTER + 1.minute do
      tracer.in_span("overdue backlog", kind: :consumer, attributes: { job_attribute => ReportWorkerHealthJob.name }) do
        ReportWorkerHealthJob.perform_now
      end
    end
    tracer.in_span("failed job", kind: :consumer, attributes: { job_attribute => DispatchDomainEventsJob.name }) do |span|
      span.status = OpenTelemetry::Trace::Status.error
    end

    @provider.force_flush
    assert_equal [ "overdue backlog", "failed job" ], @exporter.finished_spans.map(&:name)
  end

  test "durable parent and span links connect delayed work and errors omit exception text" do
    parent = ActivityMonitoring.trace("rating") { ActivityMonitoring.traceparent }
    assert_raises(RuntimeError) do
      ActivityMonitoring.trace("delivery", parent:) { raise "private input" }
    end
    ActivityMonitoring.trace("profile", parent: nil, links: [ ActivityMonitoring.link(parent) ]) { nil }
    @provider.force_flush
    rating, delivery, profile = @exporter.finished_spans
    assert_equal rating.span_id, delivery.parent_span_id
    assert_equal rating.trace_id, delivery.trace_id
    assert_equal "RuntimeError", delivery.attributes[OpenTelemetry::SemConv::ERROR::ERROR_TYPE]
    assert_equal rating.span_id, profile.links.first.span_context.span_id
    assert_not_equal rating.trace_id, profile.trace_id
    assert_empty Array(delivery.events)
  end
end
