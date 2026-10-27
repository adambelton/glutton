require "test_helper"
require "timeout"
require_relative "../support/film_analysis_helpers"

class FilmAnalysisConcurrencyTest < ActiveSupport::TestCase
  include FilmAnalysisHelpers
  self.use_transactional_tests = false

  setup do
    @film = Film.create!(title: "Concurrent analysis")
    @dimension = FilmQuality::Dimensions::EMOTIONAL_CHARACTER
    @film_ids = [ @film.id ]
    @threads = []
  end

  teardown do
    @threads.each { |thread| thread.kill if thread.alive?; thread.join }
    FilmQuality.skip_callback(:create, :before, @callback, raise: false) if @callback
    analyses = FilmAnalysis.where(film_id: @film_ids)
    associations = AnalysisQuality.where(film_analysis_id: analyses.select(:id))
    film_quality_ids = associations.pluck(:film_quality_id)
    associations.delete_all
    analyses.delete_all
    FilmQuality.where(id: film_quality_ids).delete_all
    Film.where(id: @film_ids).delete_all
  end

  test "concurrent publication of the same draft succeeds only once" do
    assert_competing_publication
  end

  test "concurrent publication replaces the current analysis only once" do
    previous = publish_analysis(prepare_analysis)
    winner = assert_competing_publication
    assert_equal winner, previous.reload.superseded_by
    assert_equal winner.published_at, previous.superseded_at
    assert_equal 2, @film.film_analyses.where.not(published_at: nil).count
  end

  test "concurrent preparation cannot create two drafts" do
    results = race { prepare_analysis }
    draft = @film.film_analyses.draft.sole
    assert_equal 2, results.count(draft)
    assert_empty @film.film_analyses.current
    assert_empty draft.analysis_qualities
  end

  test "different films racing to introduce one shared quality reuse its identity" do
    other_film = Film.create!(title: "Another concurrent analysis")
    @film_ids << other_film.id
    drafts = [ prepare_analysis, prepare_analysis(film: other_film, quality_candidates: [ analysis_candidate(name: "SUSTAINED DREAD") ]) ]
    ready, release = Queue.new, Queue.new
    @callback = -> { ready << true; release.pop }
    FilmQuality.set_callback(:create, :before, @callback)
    @threads = drafts.map do |draft|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection { publish_analysis(draft) }
      end
    end
    Timeout.timeout(10) { 2.times { ready.pop } }
    2.times { release << true }
    results = Timeout.timeout(10) { @threads.map(&:value) }
    assert_equal 2, results.size
    assert_equal 1, FilmQuality.where(dimension: @dimension).count
    assert_equal 1, results.map { |analysis| analysis.film_qualities.sole.id }.uniq.size
    assert_equal 2, AnalysisQuality.where(film_analysis_id: drafts.map(&:id)).count
  end

  test "an edit racing publication cannot change the accepted candidate" do
    draft = prepare_analysis
    ready, release, editing = Queue.new, Queue.new, Queue.new
    @callback = -> { ready << true; release.pop }
    FilmQuality.set_callback(:create, :before, @callback)
    @threads << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { publish_analysis(draft) }
    end
    Timeout.timeout(10) { ready.pop }
    @threads << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        editing << true
        begin
          @film.edit_analysis!(quality_candidates: [ analysis_candidate(name: "Changed during publication") ])
        rescue FilmKnowledge::AnalysisNotEditable => error
          error
        end
      end
    end
    Timeout.timeout(10) { editing.pop }
    release << true
    results = Timeout.timeout(10) { @threads.map(&:value) }
    assert_equal draft, results.first
    assert_equal results.last, @film.film_analyses.draft.sole
    assert_equal "Changed during publication", results.last.quality_candidates.sole.fetch("name")
    assert_equal "Sustained dread", draft.reload.quality_candidates.sole.fetch("name")
    assert_equal "Sustained dread", draft.film_qualities.sole.name
  end

  test "a direct association write racing publication is rejected after the lock is released" do
    draft = prepare_analysis
    film_quality = FilmQuality.create!(name: "Sustained dread", dimension: @dimension)
    draft_id = draft.id
    ready, release, linking = Queue.new, Queue.new, Queue.new
    callback = -> { ready << true; release.pop if id == draft_id && will_save_change_to_published_at? }
    FilmAnalysis.set_callback(:update, :before, callback)
    @threads << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { publish_analysis(draft) }
    end
    Timeout.timeout(10) { ready.pop }
    @threads << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        linking << true
        begin
          AnalysisQuality.create!(film_analysis: draft, film_quality:, evidence_references: [ "M1" ])
        rescue FilmKnowledge::AnalysisNotEditable => error
          error
        end
      end
    end
    Timeout.timeout(10) { linking.pop }
    release << true
    results = Timeout.timeout(10) { @threads.map(&:value) }
    assert_equal draft, results.first
    assert_equal FilmKnowledge::AnalysisNotEditable, results.last.class
    assert_equal 1, draft.analysis_qualities.count
  ensure
    FilmAnalysis.skip_callback(:update, :before, callback) if callback
  end

  private

  def assert_competing_publication
    draft = prepare_analysis
    results = race { publish_analysis(draft) }
    assert_equal 1, results.count(draft)
    assert_equal 1, results.grep(FilmKnowledge::NoUnpublishedAnalysis).count
    assert_equal draft, @film.film_analyses.current.sole
    assert_equal 1, draft.analysis_qualities.count
    draft.reload
  end

  def race
    ready, release, connections = Queue.new, Queue.new, Queue.new
    @threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          connections << connection.select_value("SELECT pg_backend_pid()")
          ready << true
          release.pop
          begin
            yield
          rescue FilmKnowledge::AnalysisNotEditable, FilmKnowledge::NoUnpublishedAnalysis, ActiveRecord::RecordInvalid => error
            error
          end
        end
      end
    end
    Timeout.timeout(10) { 2.times { ready.pop } }
    2.times { release << true }
    results = Timeout.timeout(10) { @threads.map(&:value) }
    assert_not_equal connections.pop, connections.pop
    results
  end
end
