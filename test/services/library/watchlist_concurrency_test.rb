require "test_helper"
require "timeout"

class Library::WatchlistConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    freeze_time
    @threads, @user_ids, @film_ids = [], [], []
    @guest = Identity::UserGuest.create!.tap { |user| @user_ids << user.id }
    @film = Registry::Film.create!(title: "Concurrent Library film").tap { |film| @film_ids << film.id }
  end

  teardown do
    @threads.each { |thread| thread.kill if thread.alive?; thread.join }
    Library::LibraryFilm.where(user_id: @user_ids).delete_all
    Identity::PendingRegistration.where(guest_user_id: @user_ids).delete_all
    Identity::Session.where(user_id: @user_ids).delete_all
    Identity::User.where(id: @user_ids).delete_all
    Registry::Film.where(id: @film_ids).delete_all
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
    connection = Identity::User.connection
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
    [ Library::LibraryFilmNotInterested, Library::AddToWatchlist, Library::AddToWatchlist, Library::WatchlistUnavailable ],
    [ Library::LibraryFilmToWatch, Library::RemoveFromWatchlist, Library::RemoveFromWatchlist, Library::FilmUnavailable ],
    [ Library::LibraryFilmToWatch, Library::RecordWatched, Library::RemoveFromWatchlist, Library::NotOnWatchlist ],
    [ Library::LibraryFilmToWatch, Library::RemoveFromWatchlist, Library::RecordWatched, Library::FilmUnavailable ],
    [ Library::LibraryFilmNotInterested, Library::AddToWatchlist, Library::RecordWatched, nil ],
    [ Library::LibraryFilmToWatch, Library::RecordWatched, Library::AddToWatchlist, Library::WatchlistUnavailable ],
    [ Library::LibraryFilmNotInterested, Library::RemoveNotInterested, Library::AddToWatchlist, Library::FilmUnavailable ],
    [ Library::LibraryFilmNotInterested, Library::AddToWatchlist, Library::RemoveNotInterested, Library::NotMarkedNotInterested ],
    [ Library::LibraryFilmToWatch, Library::MarkNotInterested, Library::MarkNotInterested, Library::DismissalUnavailable ],
    [ Library::LibraryFilmNotInterested, Library::RemoveNotInterested, Library::RemoveNotInterested, Library::FilmUnavailable ],
    [ Library::LibraryFilmNotInterested, Library::AddToWatchlist, Library::MarkNotInterested, nil ],
    [ Library::LibraryFilmToWatch, Library::MarkNotInterested, Library::AddToWatchlist, nil ],
    [ Library::LibraryFilmToWatch, Library::RecordWatched, Library::MarkNotInterested, Library::DismissalUnavailable ],
    [ Library::LibraryFilmToWatch, Library::MarkNotInterested, Library::RecordWatched, Library::AlreadyWatched ]
  ].each do |source, first, second, failure|
    test "#{first} before #{second} serializes on the existing relationship" do
      @entry = source.create!(user: @guest, film: @film)
      contender = result = nil
      Identity::User.transaction do
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
        assert_not Library::LibraryFilm.exists?(user_id: @guest.id, film_id: @film.id)
      else
        assert_equal @entry.id, Library::LibraryFilm.find_by!(user_id: @guest.id, film_id: @film.id).id
      end
    end
  end

  test "removal cannot enter between existing-entry lookup and watched transition" do
    @entry = Library::LibraryFilmToWatch.create!(user: @guest, film: @film)
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
    Library::LibraryFilm.set_callback(:find, :after, callback)
    result = call(Library::RecordWatched)
    assert_equal :rejected, Timeout.timeout(5) { contender.value }
    assert_equal @entry.id, result.id
    assert_not Library::LibraryFilm.find(@entry.id).can_watch?
  ensure
    Library::LibraryFilm.skip_callback(:find, :after, callback, raise: false) if callback
  end
end
