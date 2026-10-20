require "test_helper"
require "timeout"

class FilmKnowledge::ImportTmdbFilmConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    @threads&.each { |thread| thread.kill if thread.alive?; thread.join }
    Film.skip_callback(:create, :before, @callback, raise: false) if @callback
    Film.where(tmdb_id: 80000001).delete_all
  end

  test "concurrent inserts return the same identity after a real unique index race" do
    ready, release = Queue.new, Queue.new
    @callback = -> { ready << true; release.pop }
    Film.set_callback(:create, :before, @callback)
    pids = Queue.new
    client = Object.new
    client.define_singleton_method(:movie) do |tmdb_id:|
      connection = ActiveRecord::Base.connection
      raise "network called inside transaction" if connection.transaction_open?
      pids << connection.select_value("SELECT pg_backend_pid()")
      { "id" => tmdb_id, "title" => "Concurrent" }
    end
    @threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          FilmKnowledge::ImportTmdbFilm.call(tmdb_id: 80000001, client:)
        end
      end
    end
    Timeout.timeout(5) { 2.times { ready.pop } }
    2.times { release << true }
    films = Timeout.timeout(5) { @threads.map(&:value) }
    assert_equal 1, films.map(&:id).uniq.size
    assert_equal 1, Film.where(tmdb_id: 80000001).count
    assert_not_equal pids.pop, pids.pop
  end

  test "a winner committed after lookup is returned when uniqueness validation runs" do
    ready, release = Queue.new, Queue.new
    client = Object.new
    client.define_singleton_method(:movie) do |tmdb_id:|
      ready << true
      release.pop
      { "id" => tmdb_id, "title" => "Fetched" }
    end
    @threads = [ Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        FilmKnowledge::ImportTmdbFilm.call(tmdb_id: 80000001, client:)
      end
    end ]
    Timeout.timeout(5) { ready.pop }
    winner = Film.create!(tmdb_id: 80000001, title: "Keep local winner", metadata: { local: true })
    release << true
    returned = Timeout.timeout(5) { @threads.first.value }
    assert_equal winner.id, returned.id
    assert_equal winner.attributes, returned.attributes
    assert_equal 1, Film.where(tmdb_id: 80000001).count
  end
end
