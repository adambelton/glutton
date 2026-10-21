require "test_helper"
require "timeout"

class Ratings::ConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    freeze_time
    @threads = []
    @user = UserGuest.create!
    @film = Film.create!(title: "Concurrent Ratings film")
    @rating_film = RatingFilm.create!(user: @user, film: @film)
  end

  teardown do
    @threads.each { |thread| thread.kill if thread.alive?; thread.join }
    PendingRegistration.where(guest_user_id: @user.id).delete_all
    Session.where(user_id: @user.id).delete_all
    User.where(id: @user.id).delete_all
    Film.where(id: @film.id).delete_all
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

  def candidates
    Ratings::NextCandidates.call(user_id: @user.id)
  end

  def claim
    pending = Identity::PrepareRegistration.call(email_address: "ratings-race@example.test", guest_user_id: @user.id,
      password: "a long password phrase", password_confirmation: "a long password phrase")
    token = Identity::RegistrationConfirmation.token_for(pending_registration_id: pending.id)
    Identity::CompleteRegistration.call(token:)
  end

  test "concurrent reads return the same candidates without creating records" do
    first = contender = nil
    User.transaction do
      first = candidates
      contender = blocked { candidates }
    end
    assert_equal first.map(&:id), Timeout.timeout(5) { contender.value }.map(&:id)
    assert_equal 1, RatingFilm.where(user: @user).count
  end

  def dismiss
    Ratings::Dismiss.call(user_id: @user.id, rating_film_id: @rating_film.id)
  end

  test "concurrent dismissals have one winner and an explicit duplicate failure" do
    candidates
    contender = nil
    User.transaction do
      dismiss
      contender = blocked do
        dismiss
      rescue Ratings::DismissalUnavailable
        :already_dismissed
      end
    end
    assert_equal :already_dismissed, Timeout.timeout(5) { contender.value }
    assert @rating_film.reload.dismissed?
  end

  test "selection waiting across expiry rejects the freshly inactive owner" do
    contender = nil
    User.transaction do
      @user.lock!
      contender = blocked do
        candidates
      rescue Ratings::IdentityUnavailable
        :inactive
      end
      travel UserGuest::EXPIRY_DURATION
    end
    assert_equal :inactive, Timeout.timeout(5) { contender.value }
    assert_not @rating_film.reload.dismissed?
  end

  test "cleanup wins before a waiting dismissal and removes ratings activity but preserves film" do
    candidates
    contender = nil
    travel UserGuest::EXPIRY_DURATION
    User.transaction do
      @user.lock!
      contender = blocked do
        dismiss
      rescue Ratings::IdentityUnavailable
        :inactive
      end
      assert_equal 1, Identity::CleanupExpiredAccounts.call[:guests_deleted]
    end
    assert_equal :inactive, Timeout.timeout(5) { contender.value }
    assert_not User.exists?(@user.id)
    assert_not RatingFilm.exists?(@rating_film.id)
    assert Film.exists?(@film.id)
  end

  test "claim preserves activity and a waiting dismissal succeeds past the old guest deadline" do
    candidates
    contender = nil
    User.transaction do
      @user.lock!
      assert_equal @user.id, claim.user_id
      contender = blocked { dismiss }
      travel UserGuest::EXPIRY_DURATION
    end
    assert_equal @rating_film.id, Timeout.timeout(5) { contender.value }.id
    assert @rating_film.reload.dismissed?
    assert_empty candidates
    assert_equal 0, Identity::CleanupExpiredAccounts.call[:guests_deleted]
  end

  test "claim winning against cleanup preserves dismissal" do
    candidates
    dismiss
    contender = nil
    User.transaction do
      @user.lock!
      claim
      travel UserGuest::EXPIRY_DURATION
      contender = blocked { Identity::CleanupExpiredAccounts.call }
    end
    assert_equal 0, Timeout.timeout(5) { contender.value }[:guests_deleted]
    assert @rating_film.reload.dismissed?
    assert_empty candidates
  end

  def submit
    Ratings::SubmitRating.call(user_id: @user.id, rating_film_id: @rating_film.id, value: Rating::Values::ENJOYED)
  end

  def rating_events
    DomainEvent.joins(:domain_event_stream).where(domain_event_streams: {
      user_id: @user.id, publisher: Ratings::EVENTS_PUBLISHING_DOMAIN
    })
  end

  test "competing first submissions produce one rating one event and an explicit failure" do
    contender = nil
    User.transaction do
      submit
      contender = blocked do
        submit
      rescue Ratings::AlreadyRated
        :already_rated
      end
    end
    assert_equal :already_rated, Timeout.timeout(5) { contender.value }
    assert_equal 1, @rating_film.ratings.count
    assert_equal 1, rating_events.count
  end

  test "submission waiting across expiry rejects freshly inactive owner" do
    contender = nil
    User.transaction do
      @user.lock!
      contender = blocked do
        submit
      rescue Ratings::IdentityUnavailable
        :inactive
      end
      travel UserGuest::EXPIRY_DURATION
    end
    assert_equal :inactive, Timeout.timeout(5) { contender.value }
    assert_empty @rating_film.ratings
    assert_empty rating_events
  end

  test "cleanup before waiting submission cannot resurrect activity" do
    contender = nil
    travel UserGuest::EXPIRY_DURATION
    User.transaction do
      @user.lock!
      contender = blocked do
        submit
      rescue Ratings::IdentityUnavailable
        :inactive
      end
      assert_equal 1, Identity::CleanupExpiredAccounts.call[:guests_deleted]
    end
    assert_equal :inactive, Timeout.timeout(5) { contender.value }
    assert_not RatingFilm.exists?(@rating_film.id)
    assert_empty Rating.where(rating_film_id: @rating_film.id)
    assert_empty rating_events
    assert Film.exists?(@film.id)
  end

  test "cleanup removes saved rating and event but retains the shared film" do
    rating = submit
    assert_equal 1, rating_events.count
    travel UserGuest::EXPIRY_DURATION
    assert_equal 1, Identity::CleanupExpiredAccounts.call[:guests_deleted]
    assert_not Rating.exists?(rating.id)
    assert_not RatingFilm.exists?(@rating_film.id)
    assert_empty rating_events
    assert Film.exists?(@film.id)
  end

  test "claim before waiting submission preserves owner and allows rating past guest deadline" do
    contender = nil
    User.transaction do
      @user.lock!
      assert_equal @user.id, claim.user_id
      contender = blocked { submit }
      travel UserGuest::EXPIRY_DURATION
    end
    rating = Timeout.timeout(5) { contender.value }
    assert_equal @rating_film.id, rating.rating_film_id
    assert_equal Rating::Values::ENJOYED, rating.reload.value
    assert_equal @user.id, rating_events.sole.payload["user_id"]
    assert_equal 0, Identity::CleanupExpiredAccounts.call[:guests_deleted]
  end

  test "claim winning against cleanup retains saved rating and stream identity" do
    rating = submit
    event = rating_events.sole
    contender = nil
    User.transaction do
      @user.lock!
      claim
      travel UserGuest::EXPIRY_DURATION
      contender = blocked { Identity::CleanupExpiredAccounts.call }
    end
    assert_equal 0, Timeout.timeout(5) { contender.value }[:guests_deleted]
    assert_equal Rating::Values::ENJOYED, rating.reload.value
    assert_equal @rating_film.id, rating.rating_film_id
    assert_equal @user.id, @rating_film.reload.user_id
    assert_equal event.id, rating_events.sole.id
    assert_equal event.domain_event_stream_id, rating_events.sole.domain_event_stream_id
  end
end
