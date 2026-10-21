require "test_helper"
require "timeout"

class Library::WatchlistConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    freeze_time
    @threads, @user_ids, @film_ids = [], [], []
    @guest = UserGuest.create!.tap { |user| @user_ids << user.id }
    @film = Film.create!(title: "Concurrent Library film").tap { |film| @film_ids << film.id }
  end

  teardown do
    @threads.each { |thread| thread.kill if thread.alive?; thread.join }
    LibraryFilm.where(user_id: @user_ids).delete_all
    PendingRegistration.where(guest_user_id: @user_ids).delete_all
    Session.where(user_id: @user_ids).delete_all
    User.where(id: @user_ids).delete_all
    Film.where(id: @film_ids).delete_all
  end

  def blocked(&operation)
    ready = Queue.new
    thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        ready << connection.select_value("SELECT pg_backend_pid()")
        operation.call
      end
    end
    @threads << thread
    pid = Timeout.timeout(5) { ready.pop }
    connection = User.connection
    Timeout.timeout(5) do
      until connection.uncached { connection.select_value("SELECT cardinality(pg_blocking_pids(#{pid}))") }.positive?
        sleep 0.01
      end
    end
    thread
  end

  def add
    Library::AddToWatchlist.call(user_id: @guest.id, film_id: @film.id)
  end

  def remove
    Library::RemoveFromWatchlist.call(user_id: @guest.id, film_id: @film.id)
  end

  def watch
    Library::RecordWatched.call(user_id: @guest.id, film_id: @film.id)
  end

  test "duplicate adds serializes against fresh state" do
    contender = first = nil
    User.transaction do
      first = add
      contender = blocked do
        begin
          add
        rescue Library::WatchlistUnavailable
          :rejected
        end
      end
    end
    result = Timeout.timeout(5) { contender.value }
    assert_equal :rejected, result
    assert_equal 1, LibraryFilm.where(user_id: @guest.id, film_id: @film.id).count
    row = LibraryFilm.find_by!(user_id: @guest.id, film_id: @film.id)
    assert row.can_watch?
    assert_equal first.id, row.id
  end

  test "concurrent reconsideration transitions once and rejects the waiting request" do
    original = LibraryFilmNotInterested.create!(user: @guest, film: @film)
    contender = nil
    User.transaction do
      assert_equal original.id, add.id
      contender = blocked do
        begin
          add
        rescue Library::WatchlistUnavailable
          :rejected
        end
      end
    end
    assert_equal :rejected, Timeout.timeout(5) { contender.value }
    assert_equal 1, LibraryFilm.where(user_id: @guest.id, film_id: @film.id).count
    row = LibraryFilm.find(original.id)
    assert_equal original.created_at, row.created_at
    assert row.can_watch?
  end

  test "duplicate removes serializes against fresh state" do
    original = add
    contender = first = nil
    User.transaction do
      first = remove
      contender = blocked do
        begin
          remove
        rescue Library::NotOnWatchlist
          :rejected
        end
      end
    end
    result = Timeout.timeout(5) { contender.value }
    assert_equal :rejected, result
    assert_equal 0, LibraryFilm.where(user_id: @guest.id, film_id: @film.id).count
  end

  test "watched before remove serializes against fresh state" do
    original = add
    contender = first = nil
    User.transaction do
      first = watch
      contender = blocked do
        begin
          remove
        rescue Library::NotOnWatchlist
          :rejected
        end
      end
    end
    result = Timeout.timeout(5) { contender.value }
    assert_equal :rejected, result
    assert_equal 1, LibraryFilm.where(user_id: @guest.id, film_id: @film.id).count
    row = LibraryFilm.find_by!(user_id: @guest.id, film_id: @film.id)
    assert_not row.can_watch?
    assert_equal first.id, row.id
  end

  test "remove before watched serializes against fresh state" do
    original = add
    contender = first = nil
    User.transaction do
      first = remove
      contender = blocked do
        watch
      end
    end
    result = Timeout.timeout(5) { contender.value }
    assert result.persisted?
    assert_equal 1, LibraryFilm.where(user_id: @guest.id, film_id: @film.id).count
    row = LibraryFilm.find_by!(user_id: @guest.id, film_id: @film.id)
    assert_not row.can_watch?
    assert_not_equal original.id, row.id
  end

  test "add before watched serializes against fresh state" do
    contender = first = nil
    User.transaction do
      first = add
      contender = blocked do
        watch
      end
    end
    result = Timeout.timeout(5) { contender.value }
    assert result.persisted?
    assert_equal 1, LibraryFilm.where(user_id: @guest.id, film_id: @film.id).count
    row = LibraryFilm.find_by!(user_id: @guest.id, film_id: @film.id)
    assert_not row.can_watch?
    assert_equal first.id, row.id
  end

  test "watched before add serializes against fresh state" do
    contender = first = nil
    User.transaction do
      first = watch
      contender = blocked do
        begin
          add
        rescue Library::WatchlistUnavailable
          :rejected
        end
      end
    end
    result = Timeout.timeout(5) { contender.value }
    assert_equal :rejected, result
    assert_equal 1, LibraryFilm.where(user_id: @guest.id, film_id: @film.id).count
    row = LibraryFilm.find_by!(user_id: @guest.id, film_id: @film.id)
    assert_not row.can_watch?
    assert_equal first.id, row.id
  end
end
