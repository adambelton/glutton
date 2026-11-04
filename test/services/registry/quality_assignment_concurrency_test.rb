require "test_helper"
require "timeout"
require_relative "../../support/quality_assessment_sources"

class Registry::QualityAssignmentConcurrencyTest < ActiveSupport::TestCase
  include QualityAssessmentSources
  self.use_transactional_tests = false

  class PausedClient < QualityAssessmentSources::Client
    def initialize(ready:, release:)
      super()
      @ready, @release = ready, release
    end

    def answer(state:, questions:, phase:)
      if phase == "quality-support"
        connection = ActiveRecord::Base.connection
        raise "provider work inside transaction" if connection.transaction_open?
        @ready << connection.select_value("SELECT pg_backend_pid()")
        @release.pop
      end
      super
    end
  end

  setup do
    @film = imported_assignment_film(tmdb_id: 800005)
    @quality = assessment_quality(name: "Concurrent assessment fixture")
    @threads = []
  end

  teardown do
    @threads.each { |thread| thread.kill.join if thread.alive? }
    Registry::FilmQuality.skip_callback(:create, :before, @callback, raise: false) if @callback
    # Remove only these disposable concurrency fixtures; no domain mutation is simulated here.
    Registry::FilmQuality.where(film_id: @film.id).delete_all
    Registry::FilmQualityEval.where(film_id: @film.id).delete_all
    Registry::Film.where(id: @film.id).delete_all
    Registry::Quality.where(id: [ @quality.id, @added_quality&.id ]).delete_all
  end

  def start_assignment(client:)
    @threads << Thread.new do
      Thread.current.report_on_exception = false
      ActiveRecord::Base.connection_pool.with_connection do
        { result: Registry::AssignInitialFilmQualities.call(film_id: @film.id, client:) }
      rescue Registry::AssignmentFailed => error
        { error: }
      end
    end
    @threads.last
  end

  test "parallel assessments write once and report the losing action explicitly" do
    ready, release = Queue.new, Queue.new
    2.times { start_assignment(client: PausedClient.new(ready:, release:)) }
    pids = Timeout.timeout(5) { 2.times.map { ready.pop } }
    assert_equal 2, pids.uniq.size
    2.times { release << true }
    results = Timeout.timeout(5) { @threads.map(&:value) }
    assigned = @film.reload
    successful = results.filter_map { |outcome| outcome[:result] }.sole
    assert_equal assigned, successful.fetch(:film)
    failure = results.filter_map { |outcome| outcome[:error] }.sole
    assert_equal :already_assigned, failure.reason
    assert_equal 2, assigned.film_quality_evals.count
    assert_equal [ successful.fetch(:film_quality_eval).id ], assigned.film_qualities.pluck(:film_quality_eval_id).uniq
    assert_equal [ @quality.id ], assigned.quality_ids
    assert_equal [ @quality.id ], successful.fetch(:film_quality_eval).output.fetch("selected_quality_ids")
  end

  test "vocabulary membership cannot change while a completed assessment is being applied" do
    ready, release = Queue.new, Queue.new
    film_id = @film.id
    @callback = lambda do |film_quality|
      if film_quality.film_id == film_id
        ready << true
        release.pop
      end
    end
    Registry::FilmQuality.set_callback(:create, :before, @callback)
    worker = start_assignment(client: Client.new)
    begin
      Timeout.timeout(5) { ready.pop }
    rescue Timeout::Error
      raise "Assignment stopped before write: #{worker.value.fetch(:error).reason}" unless worker.alive?
      raise
    end
    assert_raises(ActiveRecord::LockWaitTimeout) do
      Registry::Quality.transaction do
        Registry::Quality.connection.execute("SET LOCAL lock_timeout = '150ms'")
        assessment_quality(name: "Blocked vocabulary insert")
      end
    end
    release << true
    returned = Timeout.timeout(5) { worker.value }.fetch(:result)
    assert_equal @film.id, returned.fetch(:film).id
    @added_quality = assessment_quality(name: "Later vocabulary insert")
    assert_not_includes returned.fetch(:film_quality_eval).output.fetch("definitions").map { |definition| definition.fetch("id") }, @added_quality.id
  end
end
