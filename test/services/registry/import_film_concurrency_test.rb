require "test_helper"
require "timeout"
require_relative "../../support/film_import_sources"

class Registry::ImportFilmConcurrencyTest < ActiveSupport::TestCase
  include FilmImportSources
  self.use_transactional_tests = false

  teardown do
    @threads&.each { |thread| thread.kill.join if thread.alive? }
    Registry::Film.skip_callback(:create, :before, @callback, raise: false) if @callback
    Registry::Film.where(tmdb_id: [ 80000001, 80000002 ]).delete_all
  end

  def start_import(tmdb_id: 80000001, tmdb_client: tmdb_source(payload: { "id" => tmdb_id, "title" => "Alien" }), wikipedia_client: wikipedia_source)
    @threads ||= []
    @threads << Thread.new do
      Thread.current.report_on_exception = false
      ActiveRecord::Base.connection_pool.with_connection do
        Registry::ImportFilm.call(tmdb_id:, tmdb_client:, wikidata_client: wikidata_source, wikipedia_client:)
      rescue Registry::ImportIncomplete => error
        error
      end
    end
    @threads.last
  end

  test "a real unique index race gives one complete film and one explicit conflict" do
    ready, release = Queue.new, Queue.new
    @callback = lambda do |film|
      raise "initial insert lacks sources" unless film.has_source_context?
      ready << true
      release.pop
    end
    Registry::Film.set_callback(:create, :before, @callback)
    pids = Queue.new
    client = tmdb_source
    client.define_singleton_method(:movie) do |tmdb_id:|
      connection = ActiveRecord::Base.connection
      raise "network called inside transaction" if connection.transaction_open?
      pids << connection.select_value("SELECT pg_backend_pid()")
      { "id" => tmdb_id, "title" => "Concurrent" }
    end
    2.times { start_import(tmdb_client: client) }
    Timeout.timeout(5) { 2.times { ready.pop } }
    2.times { release << true }
    results = Timeout.timeout(5) { @threads.map(&:value) }
    film = Registry::Film.find_by!(tmdb_id: 80000001)
    assert film.has_source_context?
    assert_includes results, film
    conflict = (results - [ film ]).sole
    assert_equal [ :persistence, :existing_film, 80000001 ], [ conflict.stage, conflict.reason, conflict.tmdb_id ]
    assert_equal 1, Registry::Film.where(tmdb_id: 80000001).count
    assert_not_equal pids.pop, pids.pop
  end

  test "an identity committed after lookup fails rather than returning or changing the winner" do
    ready, release = Queue.new, Queue.new
    client = tmdb_source
    client.define_singleton_method(:movie) do |tmdb_id:|
      ready << true
      release.pop
      { "id" => tmdb_id, "title" => "Fetched" }
    end
    worker = start_import(tmdb_client: client)
    Timeout.timeout(5) { ready.pop }
    winner = Registry::Film.create!(tmdb_id: 80000001, title: "Keep local winner", tmdb_metadata: { local: true })
    timestamp = winner.updated_at
    release << true
    error = Timeout.timeout(5) { worker.value }
    assert_equal [ :persistence, :existing_film ], [ error.stage, error.reason ]
    assert_equal "Keep local winner", winner.reload.title
    assert_equal({ "local" => true }, winner.tmdb_metadata)
    assert_equal({}, winner.wikipedia_context)
    assert_equal timestamp, winner.updated_at
    assert_equal 1, Registry::Film.where(tmdb_id: 80000001).count
  end

  test "different identities fetch in parallel before either film exists" do
    ready, release = Queue.new, Queue.new
    builder = method(:wikipedia_context)
    source = Object.new
    source.define_singleton_method(:context) do |tmdb_id:, **|
      raise "network called inside transaction" if ActiveRecord::Base.connection.transaction_open?
      raise "film persisted before sources returned" if Registry::Film.exists?(tmdb_id:)
      ready << tmdb_id
      release.pop
      builder.call(tmdb_id:)
    end
    [ 80000001, 80000002 ].each { |tmdb_id| start_import(tmdb_id:, wikipedia_client: source) }
    ids = Timeout.timeout(5) { 2.times.map { ready.pop } }
    assert_equal [ 80000001, 80000002 ], ids.sort
    assert_not Registry::Film.exists?(tmdb_id: ids)
    2.times { release << true }
    films = Timeout.timeout(5) { @threads.map(&:value) }
    assert_equal 2, films.map(&:id).uniq.size
    assert films.all?(&:has_source_context?)
  end
end
