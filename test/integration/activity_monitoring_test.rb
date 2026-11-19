require "test_helper"
require_relative "../support/assessed_recommendation_films"

class ActivityMonitoringTest < ActionDispatch::IntegrationTest
  include AssessedRecommendationFilms

  setup do
    @exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    @provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    @provider.add_span_processor(ActivityMonitoring::Processor.new(@exporter))
    @original = ActivityMonitoring.tracer
    ActivityMonitoring.tracer = @provider.tracer("glutton.business")
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
    Registry::Film.create!(title: "Candidate")
    get recommendation_path
    get recommendation_path
    Ratings::RefreshTasteProfilesJob.perform_now
    @provider.force_flush
    assert_equal [ "GuestSessionsController#create", "RecommendationsController#show" ], @exporter.finished_spans.map(&:name)
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
    assert_equal "RuntimeError", delivery.attributes["error.type"]
    assert_equal rating.span_id, profile.links.first.span_context.span_id
    assert_not_equal rating.trace_id, profile.trace_id
    assert_empty Array(delivery.events)
  end
end
