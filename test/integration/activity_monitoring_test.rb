require "test_helper"
require_relative "../support/assessed_recommendation_films"

class ActivityMonitoringTest < ActionDispatch::IntegrationTest
  include AssessedRecommendationFilms

  setup do
    @exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    @provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    @provider.add_span_processor(ActivityMonitoring::Processor.new(@exporter))
    @original = ActivityMonitoring.operation_tracer
    ActivityMonitoring.operation_tracer = @provider.tracer(ActivityMonitoring::Scopes::OPERATIONS)
  end

  teardown do
    ActivityMonitoring.operation_tracer = @original
    @provider.shutdown
  end

  test "ordinary reads and polling export alongside business activity" do
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
    assert_equal [ "LandingController#show", "GuestSessionsController#create", "RecommendationsController#availability",
      "RecommendationsController#show", "RecommendationsController#show", "RatingsController#new", "RatingsController#new" ], spans.map(&:name)
    operations = spans.filter_map { |span| span.attributes[ActivityMonitoring::Attributes::OPERATION] }
    assert_equal [ ActivityMonitoring::Operations::RANK_RECOMMENDATION_FILMS, ActivityMonitoring::Operations::CREATE_RATING_FILM ], operations
  end

  test "a signed-out Community request records the response and sign-in requirement" do
    get community_path, as: :json
    assert_response :unauthorized
    get community_path
    assert_redirected_to new_session_path

    @provider.force_flush
    spans = @exporter.finished_spans.select { |span| span.name == "Community::OnboardingController#show" }
    assert_equal [ 401, 302 ], spans.map { |span| span.attributes.fetch(OpenTelemetry::SemConv::HTTP::HTTP_RESPONSE_STATUS_CODE) }
    assert spans.all? { |span| span.attributes[ActivityMonitoring::Attributes::OUTCOME] == "sign_in_required" }
    assert spans.none? { |span| span.status.code == OpenTelemetry::Trace::Status::ERROR }
  end

  test "handled registration conflicts and unavailable pages record their final status" do
    get registration_path
    assert_response :unprocessable_entity
    password = "a long test password"
    user = Identity::UserRegistered.create!(email_address: "trace-registration@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current)
    post session_path, params: { email_address: user.email_address, password: }
    assert_response :see_other
    get registration_path
    assert_response :conflict

    @provider.force_flush
    spans = @exporter.finished_spans.select { |span| span.name == "RegistrationsController#show" }
    assert_equal [ 422, 409 ], spans.map { |span| span.attributes.fetch(OpenTelemetry::SemConv::HTTP::HTTP_RESPONSE_STATUS_CODE) }
    assert_equal %w[registration_unavailable registration_conflict], spans.map { |span| span.attributes.fetch(ActivityMonitoring::Attributes::OUTCOME) }
    assert spans.none? { |span| span.status.code == OpenTelemetry::Trace::Status::ERROR }
  end

  test "registration form validation records the rejected input as an expected outcome" do
    post registration_path, params: { registration: {
      email_address: "private-registration@example.test", password: "too-short", password_confirmation: "too-short",
      terms_accepted: "1", terms_version: Identity::TermsOfService.current.version,
      privacy_notice_version: Identity::PrivacyNotice.current.version
    } }
    assert_response :unprocessable_entity

    @provider.force_flush
    operation = @exporter.finished_spans.find { |span| span.name == "Identity::Registration::StartBrowserRegistration.call" }
    assert_equal "rejected", operation.attributes.fetch(ActivityMonitoring::Attributes::OUTCOME)
    assert_equal "ActiveRecord::RecordInvalid", operation.attributes.fetch(ActivityMonitoring::Attributes::REJECTION_TYPE)
    assert @exporter.finished_spans.none? { |span| span.status.code == OpenTelemetry::Trace::Status::ERROR }
    refute_includes operation.attributes.values, "private-registration@example.test"
  end

  test "a handled dependency failure still records an error for its HTTP 503" do
    token = ENV.delete("TMDB_API_READ_ACCESS_TOKEN")
    post guest_session_path
    get library_tmdb_film_search_path(query: "Alien")
    assert_response :service_unavailable

    @provider.force_flush
    request = @exporter.finished_spans.find { |span| span.name == "Library::TmdbFilmSearchController#index" }
    assert_equal 503, request.attributes.fetch(OpenTelemetry::SemConv::HTTP::HTTP_RESPONSE_STATUS_CODE)
    assert_equal OpenTelemetry::Trace::Status::ERROR, request.status.code
  ensure
    ENV["TMDB_API_READ_ACCESS_TOKEN"] = token
  end

  test "automatic candidate selection identifies the request that refills the queue" do
    post guest_session_path
    user = Identity::UserGuest.last
    first_film = Registry::Film.create!(title: "First candidate")
    Ratings::RatingFilm.create!(user:, film: first_film).dismiss!
    Registry::Film.create!(title: "Next candidate")

    assert_difference -> { Ratings::RatingFilm.where(user:).count }, 1 do
      get new_rating_path
      assert_response :success
    end
    assert_no_difference -> { Ratings::RatingFilm.where(user:).count } do
      get new_rating_path
      assert_response :success
    end
    @provider.force_flush
    requests = @exporter.finished_spans.select { |span| span.name == "RatingsController#new" }
    assert_equal 2, requests.size
    request = requests.select { |span| span.attributes.key?(ActivityMonitoring::Attributes::OPERATION) }.sole
    assert_equal ActivityMonitoring::Operations::CREATE_RATING_FILM, request.attributes.fetch(ActivityMonitoring::Attributes::OPERATION)
  end

  test "creating a rating film during Library event delivery leaves the delivery operation intact" do
    user = Identity::UserGuest.create!
    film = Registry::Film.create!(title: "Added to watchlist")
    Library::CollectionManagement::AddToWatchlist.call(user_id: user.id, film_id: film.id)
    assert_difference -> { Ratings::RatingFilm.where(user:, film:).count }, 1 do
      DispatchDomainEventsJob.perform_now
    end

    @provider.force_flush
    delivery = @exporter.finished_spans.select { |span| span.attributes[ActivityMonitoring::Attributes::SUBSCRIBER] == Ratings::EventHandlers::ConsumeLibraryEvent::SUBSCRIBER }.sole
    assert_equal "deliver #{Library::Events::FILM_ADDED_TO_WATCHLIST}", delivery.name
    refute delivery.attributes.key?(ActivityMonitoring::Attributes::OPERATION)
  end

  test "a rating without notes keeps its submission and event trace but stores no rating context" do
    user = Identity::UserGuest.create!
    film = Registry::Film.create!(title: "Plain rating")
    candidate = Ratings::RatingFilm.create!(user:, film:)
    rating = Ratings::RatingRecording::SubmitRating.call(user_id: user.id, rating_film_id: candidate.id,
      value: Ratings::Rating::Values::PRETTY_GOOD)

    assert_not Monitoring::TraceContext.exists?(rating_id: rating.id)
    @provider.force_flush
    submission = @exporter.finished_spans.select { |span| span.name == "Ratings::RatingRecording::SubmitRating.call" }.sole
    assert_equal rating.id, submission.attributes.fetch(ActivityMonitoring::Attributes::RATING_ID)
    event = DomainEvents::DomainEvent.joins(:domain_event_stream).where(name: Ratings::Events::RATING_SUBMITTED, domain_event_streams: { user_id: user.id }).sole
    parent = ActivityMonitoring.link(Monitoring::TraceContext.parent_for_event(event.id)).span_context
    assert_equal [ submission.trace_id, submission.span_id ], [ parent.trace_id, parent.span_id ]
  end

  test "business commands across domains nest in the request, preserve returns and redact failed inputs" do
    user = Identity::UserGuest.create!
    film = Registry::Film.create!(title: "Command trace")
    ActivityMonitoring.trace_operation("business workflow") do
      assert_nil Identity::Authentication::Authenticate.call(email_address: "private@example.com", password: "private password")
      entry = Library::CollectionManagement::AddToWatchlist.call(user_id: user.id, film_id: film.id)
      assert_equal film.id, entry.film_id
      recommendation = Recommendations::RecordFilmResponse.call(user_id: user.id, film_id: film.id,
        response: Recommendations::RecommendationFilm::Responses::REJECTED)
      assert_equal film.id, recommendation.film_id
      assert_raises(Registry::Errors::AssignmentFailed) do
        Registry::QualityManagement::AssignInitialFilmQualities.call(film_id: film.id)
      end
    end
    @provider.force_flush
    root = @exporter.finished_spans.find { |span| span.name == "business workflow" }
    commands = @exporter.finished_spans.select { |span| span.parent_span_id == root.span_id }
    assert_equal %w[Identity Library Recommendations Registry], commands.map { |span| span.attributes.fetch(ActivityMonitoring::Attributes::DOMAIN) }
    assignment = commands.last
    assert_equal OpenTelemetry::Trace::Status::ERROR, assignment.status.code
    assert_equal film.id, assignment.attributes.fetch(ActivityMonitoring::Attributes::FILM_ID)
    assert_empty Array(assignment.events)
    refute_includes commands.map(&:attributes).inspect, "private"
  end

  test "AI workflow failures restore the parent operation and each exporter receives only its own spans" do
    ai_exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    ai_tracer_provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    ai_tracer_provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(ai_exporter))

    ActivityMonitoring.trace_operation("workflow") do
      assert_raises(RuntimeError) do
        ActivityMonitoring.trace_ai_workflow("assessment", scope: ActivityMonitoring::Scopes::RATINGS, provider: ai_tracer_provider,
          tags: [ "assessment" ], input: { count: 1 }) do |_ai_span, tracer|
          ActivityMonitoring.trace_ai_generation("generation", tracer:) do |generation|
            generation.set_usage(input: 2, output: 1)
            ActivityMonitoring.current_operation_span.set_outcome("interrupted")
            Identity::Authentication::Authenticate.call(email_address: "private@example.com", password: "private")
            raise "private provider response"
          end
        end
      end
      ActivityMonitoring.trace_operation("recovery") { nil }
    end

    @provider.force_flush
    command, recovery, workflow = @exporter.finished_spans
    assert_equal [ "Identity::Authentication::Authenticate.call", "recovery", "workflow" ], [ command, recovery, workflow ].map(&:name)
    assert_equal [ workflow.span_id, workflow.span_id ], [ command, recovery ].map(&:parent_span_id)
    assert_equal "interrupted", workflow.attributes.fetch(ActivityMonitoring::Attributes::OUTCOME)
    generation, assessment = ai_exporter.finished_spans
    assert_equal [ "generation", "assessment" ], ai_exporter.finished_spans.map(&:name)
    assert_equal assessment.span_id, generation.parent_span_id
    assert_not_equal workflow.trace_id, assessment.trace_id
    assert_equal [ "assessment" ], generation.attributes.fetch("langfuse.trace.tags")
    assert_equal({ "input" => 2, "output" => 1 }, JSON.parse(generation.attributes.fetch("langfuse.observation.usage_details")))
    ai_exporter.finished_spans.each do |span|
      assert_equal OpenTelemetry::Trace::Status::ERROR, span.status.code
      assert_empty Array(span.events)
      refute_includes span.status.description, "private"
    end
  ensure
    ai_tracer_provider&.shutdown
  end

  test "scheduled jobs export enqueues, idle runs, overdue work and failures" do
    tracer = @provider.tracer(ActivityMonitoring::Scopes::ACTIVE_JOB)
    jobs = [ DispatchDomainEventsJob, Ratings::RefreshTasteProfilesJob, ReportWorkerHealthJob ]
    jobs.each do |job|
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
    spans = @exporter.finished_spans
    assert_equal jobs.flat_map { |job| [ "enqueue #{job.name}", "perform #{job.name}" ] } + [ "overdue backlog", "failed job" ], spans.map(&:name)
    assert_equal [ "overdue backlog" ], spans.select { |span| span.attributes[ActivityMonitoring::Attributes::OVERDUE] }.map(&:name)
    healthy_check = spans.find { |span| span.name == "perform ReportWorkerHealthJob" }
    overdue_check = spans.find { |span| span.name == "overdue backlog" }
    assert_equal "healthy", healthy_check.attributes.fetch(ActivityMonitoring::Attributes::OUTCOME)
    assert_equal "overdue", overdue_check.attributes.fetch(ActivityMonitoring::Attributes::OUTCOME)
    assert_equal OpenTelemetry::Trace::Status::ERROR, spans.last.status.code
  end

  test "durable parent and span links connect delayed work and errors omit exception text" do
    parent = ActivityMonitoring.trace_operation("rating") { ActivityMonitoring.traceparent }
    assert_raises(RuntimeError) do
      ActivityMonitoring.trace_operation("delivery", parent:) { raise "private input" }
    end
    ActivityMonitoring.trace_operation("profile", parent: nil, links: [ ActivityMonitoring.link(parent) ]) { nil }
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
