require "test_helper"
require "timeout"

class Ratings::LibraryConsumerConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    freeze_time
    @threads, @user_ids, @film_ids = [], [], []
    @guest = Identity::UserGuest.create!.tap { |user| @user_ids << user.id }
    @film = Registry::Film.create!(title: "Concurrent Library film").tap { |film| @film_ids << film.id }
    @subscription = DomainEvents::Subscriptions.all.find { |entry| entry.name == Ratings::ConsumeLibraryEvent::SUBSCRIBER }
    event = Identity::User.transaction do
      DomainEvents::Publish.call(user_id: @guest.id, publisher: Library::Events::PUBLISHING_DOMAIN,
        stream_key: "film:#{@film.id}", name: Library::Events::FILM_ADDED_TO_WATCHLIST,
        payload: { user_id: @guest.id, film_id: @film.id })
    end
    @delivery = DomainEvents::EventDelivery.create!(domain_event: event, subscriber: @subscription.name, next_attempt_at: Time.current)
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

  def claim
    request = Identity::PrepareRegistration.call(email_address: "library-race@example.test", guest_user_id: @guest.id,
      password: "a long password phrase", password_confirmation: "a long password phrase")
    token = Identity::RegistrationConfirmation.token_for(pending_registration_id: request.id)
    Identity::CompleteRegistration.call(token:)
  end

  def deliver
    DomainEvents::Deliver.call(delivery_id: @delivery.id, subscription: @subscription)
  end

  def candidate
    Ratings::RatingFilm.uncached { Ratings::RatingFilm.find_by(user: @guest, film: @film) }
  end

  test "duplicate delivery creates one held candidate" do
    contender = nil
    Identity::User.transaction do
      assert_equal :processed, deliver
      contender = blocked { deliver }
    end
    assert_equal :not_due, Timeout.timeout(5) { contender.value }
    assert_equal 1, Ratings::RatingFilm.where(user: @guest).count
    assert candidate.held?
  end

  test "automatic admission followed by waiting watchlist delivery preserves one held candidate" do
    batch = contender = nil
    Identity::User.transaction do
      batch = Ratings::NextCandidates.call(user_id: @guest.id, limit: 1)
      contender = blocked { deliver }
    end
    assert_equal :processed, Timeout.timeout(5) { contender.value }
    assert_equal batch.first.id, candidate.id
    assert candidate.held?
    assert_equal 1, Ratings::RatingFilm.where(user: @guest, film: @film).count
    assert_empty Ratings::NextCandidates.call(user_id: @guest.id)
  end

  test "submission before waiting hold preserves saved evidence" do
    row = Ratings::RatingFilm.create!(user: @guest, film: @film)
    contender = rating = nil
    Identity::User.transaction do
      rating = Ratings::SubmitRating.call(user_id: @guest.id, rating_film_id: row.id,
        value: Ratings::Rating::Values::BRILLIANT, notes: "Original")
      contender = blocked { deliver }
    end
    assert_equal :processed, Timeout.timeout(5) { contender.value }
    assert candidate.held?
    assert_equal "Original", rating.notes
    assert_empty Ratings::NextCandidates.call(user_id: @guest.id)
  end

  test "hold before waiting dismissal preserves both states" do
    contender = nil
    Identity::User.transaction do
      deliver
      row = candidate
      contender = blocked { Ratings::Dismiss.call(user_id: @guest.id, rating_film_id: row.id) }
    end
    Timeout.timeout(5) { contender.value }
    assert candidate.held?
    assert candidate.dismissed?
  end

  test "dismissal before waiting hold preserves both states" do
    row = Ratings::RatingFilm.create!(user: @guest, film: @film)
    contender = nil
    Identity::User.transaction do
      Ratings::Dismiss.call(user_id: @guest.id, rating_film_id: row.id)
      contender = blocked { deliver }
    end
    assert_equal :processed, Timeout.timeout(5) { contender.value }
    assert candidate.held?
    assert candidate.dismissed?
  end

  test "expiry while delivery waits skips candidate creation" do
    contender = nil
    Identity::User.transaction do
      @guest.lock!
      contender = blocked { deliver }
      travel Identity::UserGuest::EXPIRY_DURATION
    end
    assert_equal :skipped, Timeout.timeout(5) { contender.value }
    assert_nil candidate
  end

  test "cleanup before waiting delivery cannot resurrect activity" do
    contender = nil
    travel Identity::UserGuest::EXPIRY_DURATION
    Identity::User.transaction do
      @guest.lock!
      contender = blocked { deliver }
      assert_equal 1, Identity::CleanupExpiredAccounts.call[:guests_deleted]
    end
    assert_equal :missing, Timeout.timeout(5) { contender.value }
    assert_nil candidate
    assert_not DomainEvents::EventDelivery.exists?(@delivery.id)
    assert Registry::Film.exists?(@film.id)
  end

  test "claim preserves held candidate while later delivery succeeds past guest deadline" do
    row = Ratings::RatingFilm.create!(user: @guest, film: @film, dismissed: true)
    contender = nil
    Identity::User.transaction do
      @guest.lock!
      claim
      contender = blocked { deliver }
      travel Identity::UserGuest::EXPIRY_DURATION
    end
    assert_equal :processed, Timeout.timeout(5) { contender.value }
    assert_equal row.id, candidate.id
    assert candidate.held?
    assert candidate.dismissed?
    assert_equal 0, Identity::CleanupExpiredAccounts.call[:guests_deleted]
  end

  test "cleanup removes held activity after completed delivery" do
    deliver
    row = candidate
    travel Identity::UserGuest::EXPIRY_DURATION
    assert_equal 1, Identity::CleanupExpiredAccounts.call[:guests_deleted]
    assert_not Ratings::RatingFilm.exists?(row.id)
    assert_not DomainEvents::EventDelivery.exists?(@delivery.id)
    assert Registry::Film.exists?(@film.id)
  end

  def submit_selected_film
    row = Ratings::PrepareCandidate.call(user_id: @guest.id, film_id: @film.id)
    Ratings::SubmitRating.call(user_id: @guest.id, rating_film_id: row.id,
      value: Ratings::Rating::Values::BRILLIANT, notes: "Selected film evidence")
  end

  test "targeted admission before waiting Library delivery preserves one candidate and evidence" do
    contender = rating = nil
    Identity::User.transaction do
      rating = submit_selected_film
      contender = blocked { deliver }
    end
    assert_equal :processed, Timeout.timeout(5) { contender.value }
    assert_equal 1, Ratings::RatingFilm.where(user: @guest, film: @film).count
    assert_equal rating.rating_film_id, candidate.id
    assert candidate.held?
    assert_equal "Selected film evidence", candidate.ratings.sole.notes
    assert_equal 1, DomainEvents::DomainEvent.where(name: Ratings::Events::RATING_SUBMITTED).joins(:domain_event_stream)
      .where(domain_event_streams: { user_id: @guest.id }).count
  end

  test "Library admission before waiting targeted submission preserves its hold" do
    contender = nil
    Identity::User.transaction do
      deliver
      contender = blocked { submit_selected_film }
    end
    rating = Timeout.timeout(5) { contender.value }
    assert_equal 1, Ratings::RatingFilm.where(user: @guest, film: @film).count
    assert_equal rating.rating_film_id, candidate.id
    assert candidate.held?
    assert_equal "Selected film evidence", candidate.ratings.sole.notes
  end
end
