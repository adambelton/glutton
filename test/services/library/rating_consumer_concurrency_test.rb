require "test_helper"
require "timeout"

class Library::RatingConsumerConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    freeze_time
    @threads, @user_ids, @film_ids = [], [], []
    @guest = UserGuest.create!.tap { |user| @user_ids << user.id }
    @film = Film.create!(title: "Concurrent Library film").tap { |film| @film_ids << film.id }
    @subscription = DomainEvents::Subscriptions.all.find { |entry| entry.name == Library::ConsumeRating::SUBSCRIBER }
    event = User.transaction do
      DomainEvents::Publish.call(user_id: @guest.id, publisher: Ratings::EVENTS_PUBLISHING_DOMAIN,
        stream_key: "film:#{@film.id}", name: Ratings::Events::RATING_SUBMITTED,
        payload: { user_id: @guest.id, film_id: @film.id })
    end
    @delivery = EventDelivery.create!(domain_event: event, subscriber: @subscription.name, next_attempt_at: Time.current)
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

  def claim
    request = Identity::PrepareRegistration.call(email_address: "library-race@example.test", guest_user_id: @guest.id,
      password: "a long password phrase", password_confirmation: "a long password phrase")
    token = Identity::RegistrationConfirmation.token_for(pending_registration_id: request.id)
    Identity::CompleteRegistration.call(token:)
  end

  def deliver
    DomainEvents::Deliver.call(delivery_id: @delivery.id, subscription: @subscription)
  end

  def watched_events
    DomainEvent.joins(:domain_event_stream).where(name: Library::Events::FILM_MARKED_WATCHED,
      domain_event_streams: { user_id: @guest.id })
  end

  test "competing deliveries commit one effect and one receipt" do
    contender = nil
    User.transaction do
      assert_equal :processed, deliver
      contender = blocked { deliver }
    end
    assert_equal :not_due, Timeout.timeout(5) { contender.value }
    assert_equal 1, watched_events.count
    assert_equal EventDelivery::Statuses::PROCESSED, @delivery.reload.status
  end

  { "watchlist" => Library::AddToWatchlist, "not interested" => Library::MarkNotInterested }.each do |intent, operation|
    test "#{intent} committed first is reconciled by waiting delivery" do
      contender = entry = nil
      User.transaction do
        entry = operation.call(user_id: @guest.id, film_id: @film.id)
        contender = blocked { deliver }
      end
      assert_equal :processed, Timeout.timeout(5) { contender.value }
      assert LibraryFilmWatched.exists?(entry.id)
      assert_equal 1, watched_events.count
    end
  end

  test "delivery committed first prevents waiting unwatched intent actions" do
    [ [ Library::AddToWatchlist, Library::WatchlistUnavailable ],
      [ Library::MarkNotInterested, Library::DismissalUnavailable ] ].each do |operation, failure|
      contender = nil
      User.transaction do
        @guest.lock!
        deliver
        contender = blocked do
          operation.call(user_id: @guest.id, film_id: @film.id)
        rescue failure
          :rejected
        end
      end
      assert_equal :rejected, Timeout.timeout(5) { contender.value }
      assert LibraryFilmWatched.exists?(user: @guest, film: @film)
      assert_equal 1, watched_events.count
    end
  end

  test "expiry while delivery waits skips activity" do
    contender = nil
    User.transaction do
      @guest.lock!
      contender = blocked { deliver }
      travel UserGuest::EXPIRY_DURATION
    end
    assert_equal :skipped, Timeout.timeout(5) { contender.value }
    assert_not LibraryFilm.exists?(user: @guest)
    assert_empty watched_events
  end

  test "cleanup winning against delivery cannot resurrect owner activity" do
    contender = nil
    travel UserGuest::EXPIRY_DURATION
    User.transaction do
      @guest.lock!
      contender = blocked { deliver }
      assert_equal 1, Identity::CleanupExpiredAccounts.call[:guests_deleted]
    end
    assert_equal :missing, Timeout.timeout(5) { contender.value }
    assert_not LibraryFilm.exists?(user_id: @guest.id)
    assert_not EventDelivery.exists?(@delivery.id)
    assert Film.exists?(@film.id)
  end

  test "claim allows waiting delivery beyond former guest deadline" do
    contender = nil
    User.transaction do
      @guest.lock!
      claim
      contender = blocked { deliver }
      travel UserGuest::EXPIRY_DURATION
    end
    assert_equal :processed, Timeout.timeout(5) { contender.value }
    assert LibraryFilmWatched.exists?(user_id: @guest.id, film: @film)
    assert_equal 0, Identity::CleanupExpiredAccounts.call[:guests_deleted]
    assert_equal 1, watched_events.count
  end
end
