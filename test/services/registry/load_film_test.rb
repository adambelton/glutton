require "test_helper"
require "timeout"
require_relative "../../support/film_loading_sources"

class Registry::LoadFilmTest < ActiveSupport::TestCase
  include FilmLoadingSources
  self.use_transactional_tests = false
  TMDB_IDS = (8_900_001..8_900_010).freeze

  setup do
    @quality = assessment_quality(name: "Loading workflow quality")
    @sources = loading_sources
    @threads = []
  end

  teardown do
    @threads.each { |thread| thread.kill.join if thread.alive? }
    Registry::Film.skip_callback(:create, :before, @callback, raise: false) if @callback
    Registry::FilmQuality.skip_callback(:create, :after, @quality_callback, raise: false) if @quality_callback
    # Delete only disposable workflow fixtures; do not simulate model mutations.
    film_ids = Registry::Film.where(tmdb_id: TMDB_IDS).ids
    Registry::FilmQuality.where(film_id: film_ids).delete_all
    Registry::FilmQualityEval.where(film_id: film_ids).delete_all
    Registry::Film.where(id: film_ids).delete_all
    Registry::Quality.where(id: @quality.id).delete_all
  end

  def load_film(tmdb_id: TMDB_IDS.first, maximum_requests: 2, maximum_cost_usd: 0.02, sources: @sources)
    sources.call(tmdb_id:, maximum_requests:, maximum_cost_usd:)
  end

  test "one load persists complete sources an evaluation and its accepted qualities independently" do
    result = nil
    assert_no_difference [ "Library::LibraryFilm.count", "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      result = load_film
    end
    film, evaluation = result.values_at(:film, :film_quality_eval)
    assert film.has_source_context?
    assert_equal [ @quality ], film.qualities.to_a
    assert_equal [ evaluation.id ], result.fetch(:film_qualities).map(&:film_quality_eval_id)
    assert_equal film.id, evaluation.film_id
    assert_equal "applied", evaluation.application.fetch("status")
    assert_equal 2, evaluation.output.fetch("call_count")
    assert_empty result.fetch(:warnings)
    assert_equal [ :tmdb, :external_ids, :wikidata, :wikipedia ], @sources.source_requests.map { |request| request.fetch(:phase) }
    assert_equal 2, @sources.assessment_requests.size
  end

  test "incomplete source acquisition creates no film and never starts assessment" do
    sources = loading_sources(wikipedia_failure_ids: [ TMDB_IDS.first ])
    error = assert_raises(Registry::ImportIncomplete) { load_film(sources:) }
    assert_equal [ :wikipedia, :missing_article ], [ error.stage, error.reason ]
    assert_not Registry::Film.exists?(tmdb_id: TMDB_IDS.first)
    assert_empty sources.assessment_requests
  end

  test "assessment failure preserves imported context and a failed evaluation without qualities" do
    sources = loading_sources(assessment_failure_ids: [ TMDB_IDS.first ])
    error = assert_raises(Registry::AssignmentFailed) { load_film(sources:) }
    assert_equal :timeout, error.reason
    film = Registry::Film.find_by!(tmdb_id: TMDB_IDS.first)
    assert film.has_source_context?
    assert_not film.has_film_qualities?
    evaluation = film.film_quality_evals.sole
    assert_equal "failed", evaluation.output.fetch("status")
    assert_equal "failed", evaluation.application.fetch("status")
    assert_equal 1, sources.assessment_requests.size
  end

  test "application failure rolls back qualities while retaining the sources and evaluation" do
    @quality_callback = -> { raise ActiveRecord::StatementInvalid, "injected persistence failure" }
    Registry::FilmQuality.set_callback(:create, :after, @quality_callback)
    assert_raises(ActiveRecord::StatementInvalid) { load_film }
    film = Registry::Film.find_by!(tmdb_id: TMDB_IDS.first)
    assert film.has_source_context?
    assert_not film.has_film_qualities?
    assert_equal "persistence_error", film.film_quality_evals.sole.application.fetch("reason")
  end

  test "zero supported qualities are warned rather than reported as complete coverage" do
    result = load_film(sources: loading_sources(zero_ids: [ TMDB_IDS.first ]))
    assert_empty result.fetch(:film_qualities)
    warning = result.fetch(:warnings).sole
    assert_equal :no_qualities, warning.fetch(:reason)
    assert_equal result.fetch(:film).id, warning.fetch(:film_id)
    assert_equal "completed", result.fetch(:film_quality_eval).output.fetch("status")
    assert_equal 1, result.fetch(:film_quality_eval).output.fetch("call_count")
    assert_includes Registry::Film.without_qualities, result.fetch(:film)
  end

  test "existing identities fail before providers and preserve the original accepted result" do
    original = load_film
    sources = loading_sources
    error = assert_raises(Registry::ImportIncomplete) { load_film(sources:) }
    assert_equal :existing_film, error.reason
    assert_empty sources.source_requests
    assert_empty sources.assessment_requests
    assert_equal original.fetch(:film_quality_eval).id, original.fetch(:film).film_quality_evals.sole.id
    assert_equal 1, original.fetch(:film).film_qualities.count
  end

  test "actual request and spend guards are enforced for each film" do
    error = assert_raises(Registry::AssignmentFailed) { load_film(maximum_requests: 1) }
    assert_equal :request_limit, error.reason
    assert_equal 1, @sources.assessment_requests.size
    assert_equal [ "completed", "not_sent" ], Registry::Film.find_by!(tmdb_id: TMDB_IDS.first).film_quality_evals.sole.output.fetch("calls").map { |call| call.fetch("status") }
    sources = loading_sources
    error = assert_raises(Registry::AssignmentFailed) do
      load_film(tmdb_id: TMDB_IDS.first + 1, maximum_cost_usd: 0.00000001, sources:)
    end
    assert_equal :budget_exceeded, error.reason
    assert_empty sources.assessment_requests
    assert Registry::Film.find_by!(tmdb_id: TMDB_IDS.first + 1).has_source_context?
  end

  test "invalid limits and caller transactions are rejected before acquisition" do
    [ 0, -1, "2", 1.5, nil ].each do |maximum_requests|
      assert_raises(Registry::InvalidFilmLoad) { load_film(maximum_requests:) }
    end
    [ 0, -1, "0.02", Float::NAN, Float::INFINITY, Complex(1, 2), Rational(1, 2), nil ].each do |maximum_cost_usd|
      assert_raises(Registry::InvalidFilmLoad) { load_film(maximum_cost_usd:) }
    end
    Registry::Film.transaction do
      error = assert_raises(Registry::InvalidFilmLoad) { load_film }
      assert_equal :open_transaction, error.reason
    end
    assert_empty @sources.source_requests
  end

  test "two simultaneous loads of one identity create one complete result and one explicit conflict" do
    ready, release = Queue.new, Queue.new
    @callback = lambda do |film|
      if TMDB_IDS.cover?(film.tmdb_id)
        ready << true
        release.pop
      end
    end
    Registry::Film.set_callback(:create, :before, @callback)
    2.times do
      @threads << Thread.new do
        Thread.current.report_on_exception = false
        ActiveRecord::Base.connection_pool.with_connection { { result: load_film } }
      rescue Registry::ImportIncomplete => error
        { error: }
      end
    end
    Timeout.timeout(5) { 2.times { ready.pop } }
    2.times { release << true }
    results = Timeout.timeout(5) { @threads.map(&:value) }
    film = Registry::Film.find_by!(tmdb_id: TMDB_IDS.first)
    assert_equal 1, film.film_quality_evals.count
    assert_equal 1, film.film_qualities.count
    assert_equal film, results.filter_map { |outcome| outcome[:result] }.sole.fetch(:film)
    assert_equal :existing_film, results.filter_map { |outcome| outcome[:error] }.sole.reason
    assert_equal 2, @sources.assessment_requests.size
  end

  test "independent workers load different films with separate request allocations" do
    ready, release = Queue.new, Queue.new
    TMDB_IDS.first(2).each do |tmdb_id|
      @threads << Thread.new do
        Thread.current.report_on_exception = false
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          ready << connection.select_value("SELECT pg_backend_pid()")
          release.pop
          load_film(tmdb_id:)
        end
      end
    end
    pids = Timeout.timeout(5) { 2.times.map { ready.pop } }
    assert_equal 2, pids.uniq.size
    2.times { release << true }
    results = Timeout.timeout(5) { @threads.map(&:value) }
    assert_equal TMDB_IDS.first(2), results.map { |result| result.fetch(:film).tmdb_id }.sort
    assert_equal [ 2, 2 ], results.map { |result| result.fetch(:film_quality_eval).output.fetch("call_count") }
    assert_equal 4, @sources.assessment_requests.size
  end

  test "bounded client construction retains the existing assignment trace hierarchy" do
    exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))
    result = load_film(sources: loading_sources(tracer_provider: provider))
    root = exporter.finished_spans.find { |span| span.name == "assign-initial-film-qualities" }
    generations = exporter.finished_spans.reject { |span| span == root }
    assert_equal 2, generations.size
    assert_equal root.trace_id.unpack1("H*"), result.fetch(:film_quality_eval).output.fetch("trace_id")
    generations.each do |span|
      assert_equal root.trace_id, span.trace_id
      assert_equal root.span_id, span.parent_span_id
    end
    refute_includes exporter.finished_spans.map(&:attributes).to_json, "private-loading-test-key"
  ensure
    provider&.shutdown
  end
end
