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

  def call(operation)
    operation.call(user_id: @guest.id, library_film_id: @entry.id)
  end

  [
    [ LibraryFilmNotInterested, Library::AddToWatchlist, Library::AddToWatchlist, Library::WatchlistUnavailable ],
    [ LibraryFilmToWatch, Library::RemoveFromWatchlist, Library::RemoveFromWatchlist, Library::FilmUnavailable ],
    [ LibraryFilmToWatch, Library::RecordWatched, Library::RemoveFromWatchlist, Library::NotOnWatchlist ],
    [ LibraryFilmToWatch, Library::RemoveFromWatchlist, Library::RecordWatched, Library::FilmUnavailable ],
    [ LibraryFilmNotInterested, Library::AddToWatchlist, Library::RecordWatched, nil ],
    [ LibraryFilmToWatch, Library::RecordWatched, Library::AddToWatchlist, Library::WatchlistUnavailable ],
    [ LibraryFilmNotInterested, Library::RemoveNotInterested, Library::AddToWatchlist, Library::FilmUnavailable ],
    [ LibraryFilmNotInterested, Library::AddToWatchlist, Library::RemoveNotInterested, Library::NotMarkedNotInterested ],
    [ LibraryFilmToWatch, Library::MarkNotInterested, Library::MarkNotInterested, Library::DismissalUnavailable ],
    [ LibraryFilmNotInterested, Library::RemoveNotInterested, Library::RemoveNotInterested, Library::FilmUnavailable ],
    [ LibraryFilmNotInterested, Library::AddToWatchlist, Library::MarkNotInterested, nil ],
    [ LibraryFilmToWatch, Library::MarkNotInterested, Library::AddToWatchlist, nil ],
    [ LibraryFilmToWatch, Library::RecordWatched, Library::MarkNotInterested, Library::DismissalUnavailable ],
    [ LibraryFilmToWatch, Library::MarkNotInterested, Library::RecordWatched, Library::AlreadyWatched ]
  ].each do |source, first, second, failure|
    test "#{first} before #{second} serializes on the existing relationship" do
      @entry = source.create!(user: @guest, film: @film)
      contender = result = nil
      User.transaction do
        result = call(first)
        contender = blocked do
          begin
            call(second)
          rescue failure || StandardError => error
            raise unless failure && error.is_a?(failure)
            :rejected
          end
        end
      end
      outcome = Timeout.timeout(5) { contender.value }
      if failure
        assert_equal :rejected, outcome
      else
        assert_equal @entry.id, outcome.id
        assert_equal @entry.created_at, outcome.created_at
      end
      if result.destroyed?
        assert_not LibraryFilm.exists?(user_id: @guest.id, film_id: @film.id)
      else
        assert_equal @entry.id, LibraryFilm.find_by!(user_id: @guest.id, film_id: @film.id).id
      end
    end
  end

  test "removal cannot enter between existing-entry lookup and watched transition" do
    @entry = LibraryFilmToWatch.create!(user: @guest, film: @film)
    entry_id = @entry.id
    contender = nil
    observed = false
    test_case = self
    callback = lambda do |row|
      if row.id == entry_id && !observed
        observed = true
        contender = test_case.blocked do
          begin
            test_case.call(Library::RemoveFromWatchlist)
          rescue Library::NotOnWatchlist
            :rejected
          end
        end
      end
    end
    LibraryFilm.set_callback(:find, :after, callback)
    result = call(Library::RecordWatched)
    assert_equal :rejected, Timeout.timeout(5) { contender.value }
    assert_equal @entry.id, result.id
    assert_not LibraryFilm.find(@entry.id).can_watch?
  ensure
    LibraryFilm.skip_callback(:find, :after, callback, raise: false) if callback
  end
end
