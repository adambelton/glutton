require "test_helper"
require "timeout"

class Library::WatchedConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    freeze_time
    @threads, @user_ids, @film_ids = [], [], []
    @guest = UserGuest.create!.tap { |user| @user_ids << user.id }
    @film = Film.create!(title: "Concurrent Library film").tap { |film| @film_ids << film.id }
    @entry = LibraryFilmToWatch.create!(user: @guest, film: @film)
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

  def record
    Library::RecordWatched.call(user_id: @guest.id, library_film_id: @entry.id)
  end

  def claim
    request = Identity::PrepareRegistration.call(email_address: "library-race@example.test", guest_user_id: @guest.id,
      password: "a long password phrase", password_confirmation: "a long password phrase")
    token = Identity::RegistrationConfirmation.token_for(pending_registration_id: request.id)
    Identity::CompleteRegistration.call(token:)
  end

  test "concurrent watched transitions serialize and reject the second request without changes" do
    contender = nil
    first = attributes = nil
    User.transaction do
      first = record
      attributes = [ first.id, first.created_at, first.updated_at ]
      contender = blocked do
        begin
          record
        rescue Library::AlreadyWatched
          :already_watched
        end
      end
    end
    assert_equal :already_watched, Timeout.timeout(5) { contender.value }
    assert_equal 1, LibraryFilm.where(user_id: @guest.id, film: @film).count
    row = LibraryFilm.find_by!(user_id: @guest.id)
    assert_equal attributes, [ row.id, row.created_at, row.updated_at ]
  end

  test "claim wins before waiting cleanup and preserves the registered library" do
    freeze_time
    original = record
    contender = nil
    User.transaction do
      @guest.lock!
      claim
      travel UserGuest::EXPIRY_DURATION
      contender = blocked { Identity::CleanupExpiredAccounts.call }
    end
    assert_equal({ guests_deleted: 0, pending_registrations_deleted: 0 }, Timeout.timeout(5) { contender.value })
    assert_equal original.id, LibraryFilm.find_by!(user_id: @guest.id, film_id: @film.id).id
    assert_raises(Library::AlreadyWatched) { record }
  end

  test "cleanup wins before waiting write and cannot leave orphaned library activity" do
    freeze_time
    record
    travel UserGuest::EXPIRY_DURATION
    contender = nil
    User.transaction do
      @guest.lock!
      contender = blocked do
        begin
          record
        rescue Library::IdentityUnavailable
          :rejected
        end
      end
      assert_equal 1, Identity::CleanupExpiredAccounts.call[:guests_deleted]
    end
    assert_equal :rejected, Timeout.timeout(5) { contender.value }
    assert_not User.exists?(@guest.id)
    assert_not LibraryFilm.exists?(user_id: @guest.id)
    assert Film.exists?(@film.id)
  end

  test "waiting write re-reads a claimed guest as registered after the old guest deadline" do
    freeze_time
    contender = nil
    User.transaction do
      @guest.lock!
      claim
      travel UserGuest::EXPIRY_DURATION
      contender = blocked { record }
    end
    assert Timeout.timeout(5) { contender.value }.persisted?
    assert_equal 1, LibraryFilm.where(user_id: @guest.id).count
  end
end
