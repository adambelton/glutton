require "test_helper"
require "timeout"

class Ratings::ConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    freeze_time
    @threads = []
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "Concurrent Ratings film")
    @catalogue_films = []
    @rating_film = Ratings::RatingFilm.create!(user: @user, film: @film)
  end

  teardown do
    @threads.each { |thread| thread.kill if thread.alive?; thread.join }
    Identity::PendingRegistration.where(guest_user_id: @user.id).delete_all
    Identity::Session.where(user_id: @user.id).delete_all
    Identity::User.where(id: @user.id).delete_all
    Registry::Film.where(id: [ @film.id ] + @catalogue_films.map(&:id)).delete_all
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

  def candidates(**options)
    Ratings::NextCandidates.call(user_id: @user.id, **options)
  end

  def claim
    pending = Identity::PrepareRegistration.call(email_address: "ratings-race@example.test", guest_user_id: @user.id,
      password: "a long password phrase", password_confirmation: "a long password phrase")
    token = Identity::RegistrationConfirmation.token_for(pending_registration_id: pending.id)
    Identity::CompleteRegistration.call(token:)
  end

  test "concurrent reads return the same candidates without creating records" do
    first = contender = nil
    Identity::User.transaction do
      first = candidates
      contender = blocked { candidates }
    end
    assert_equal first.map(&:id), Timeout.timeout(5) { contender.value }.map(&:id)
    assert_equal 1, Ratings::RatingFilm.where(user: @user).count
  end

  def unqueued_film(votes:)
    film = Registry::Film.create!(title: "Unqueued", tmdb_metadata: { details: { vote_count: votes } })
    @catalogue_films << film
    film
  end

  test "concurrent automatic requests fill the shortfall once and return the same batch" do
    first_film = unqueued_film(votes: 100)
    unqueued_film(votes: 50)
    batch = contender = nil
    Identity::User.transaction do
      batch = candidates(limit: 2)
      contender = blocked { candidates(limit: 2) }
    end
    assert_equal batch.map(&:id), Timeout.timeout(5) { contender.value }.map(&:id)
    assert_equal 2, Ratings::RatingFilm.where(user: @user).count
    assert_equal [ @film.id, first_film.id ], batch.map(&:film_id)
  end

  test "automatic admission and waiting targeted admission share one candidate" do
    film = unqueued_film(votes: 100)
    batch = contender = nil
    Identity::User.transaction do
      batch = candidates(limit: 2)
      contender = blocked { Ratings::PrepareCandidate.call(user_id: @user.id, film_id: film.id) }
    end
    assert_equal batch.last.id, Timeout.timeout(5) { contender.value }.id
    assert_equal 1, Ratings::RatingFilm.where(user: @user, film:).count
    assert_not batch.last.reload.held?
    assert_not batch.last.dismissed?
  end

  def dismiss
    Ratings::Dismiss.call(user_id: @user.id, rating_film_id: @rating_film.id)
  end

  test "concurrent dismissals have one winner and an explicit duplicate failure" do
    candidates
    contender = nil
    Identity::User.transaction do
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
    Identity::User.transaction do
      @user.lock!
      contender = blocked do
        candidates
      rescue Ratings::IdentityUnavailable
        :inactive
      end
      travel Identity::UserGuest::EXPIRY_DURATION
    end
    assert_equal :inactive, Timeout.timeout(5) { contender.value }
    assert_not @rating_film.reload.dismissed?
  end

  test "cleanup wins before a waiting dismissal and removes ratings activity but preserves film" do
    candidates
    contender = nil
    travel Identity::UserGuest::EXPIRY_DURATION
    Identity::User.transaction do
      @user.lock!
      contender = blocked do
        dismiss
      rescue Ratings::IdentityUnavailable
        :inactive
      end
      assert_equal 1, Identity::CleanupExpiredAccounts.call[:guests_deleted]
    end
    assert_equal :inactive, Timeout.timeout(5) { contender.value }
    assert_not Identity::User.exists?(@user.id)
    assert_not Ratings::RatingFilm.exists?(@rating_film.id)
    assert Registry::Film.exists?(@film.id)
  end

  test "claim preserves activity and a waiting dismissal succeeds past the old guest deadline" do
    candidates
    contender = nil
    Identity::User.transaction do
      @user.lock!
      assert_equal @user.id, claim.user_id
      contender = blocked { dismiss }
      travel Identity::UserGuest::EXPIRY_DURATION
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
    Identity::User.transaction do
      @user.lock!
      claim
      travel Identity::UserGuest::EXPIRY_DURATION
      contender = blocked { Identity::CleanupExpiredAccounts.call }
    end
    assert_equal 0, Timeout.timeout(5) { contender.value }[:guests_deleted]
    assert @rating_film.reload.dismissed?
    assert_empty candidates
  end

  def submit(expression_texts: [ "Atmosphere", "  Ending!  " ])
    Ratings::SubmitRating.call(user_id: @user.id, rating_film_id: @rating_film.id, value: Ratings::Rating::Values::PRETTY_GOOD, expression_texts:)
  end

  def rating_events
    DomainEvents::DomainEvent.joins(:domain_event_stream).where(domain_event_streams: {
      user_id: @user.id, publisher: Ratings::Events::PUBLISHING_DOMAIN
    })
  end

  test "competing first submissions produce one rating one event and an explicit failure" do
    contender = nil
    Identity::User.transaction do
      submit
      contender = blocked do
        submit(expression_texts: [ "Losing submission" ])
      rescue Ratings::AlreadyRated
        :already_rated
      end
    end
    assert_equal :already_rated, Timeout.timeout(5) { contender.value }
    assert_equal [ "Atmosphere", "  Ending!  " ], @rating_film.ratings.sole.rating_expressions.pluck(:text)
    assert_equal 1, @rating_film.ratings.count
    assert_equal 1, rating_events.count
  end

  test "submission waiting across expiry rejects freshly inactive owner" do
    contender = nil
    Identity::User.transaction do
      @user.lock!
      contender = blocked do
        submit
      rescue Ratings::IdentityUnavailable
        :inactive
      end
      travel Identity::UserGuest::EXPIRY_DURATION
    end
    assert_equal :inactive, Timeout.timeout(5) { contender.value }
    assert_empty @rating_film.ratings
    assert_empty rating_events
  end

  test "cleanup before waiting submission cannot resurrect activity" do
    contender = nil
    travel Identity::UserGuest::EXPIRY_DURATION
    Identity::User.transaction do
      @user.lock!
      contender = blocked do
        submit
      rescue Ratings::IdentityUnavailable
        :inactive
      end
      assert_equal 1, Identity::CleanupExpiredAccounts.call[:guests_deleted]
    end
    assert_equal :inactive, Timeout.timeout(5) { contender.value }
    assert_not Ratings::RatingFilm.exists?(@rating_film.id)
    assert_empty Ratings::Rating.where(rating_film_id: @rating_film.id)
    assert_empty rating_events
    assert Registry::Film.exists?(@film.id)
  end

  test "cleanup removes saved rating and event but retains the shared film" do
    rating = submit
    assert_equal 1, rating_events.count
    travel Identity::UserGuest::EXPIRY_DURATION
    assert_equal 1, Identity::CleanupExpiredAccounts.call[:guests_deleted]
    assert_not Ratings::RatingExpression.where(rating_id: rating.id).exists?
    assert_not Ratings::Rating.exists?(rating.id)
    assert_not Ratings::RatingFilm.exists?(@rating_film.id)
    assert_empty rating_events
    assert Registry::Film.exists?(@film.id)
  end

  test "claim before waiting submission preserves owner and allows rating past guest deadline" do
    contender = nil
    Identity::User.transaction do
      @user.lock!
      assert_equal @user.id, claim.user_id
      contender = blocked { submit }
      travel Identity::UserGuest::EXPIRY_DURATION
    end
    rating = Timeout.timeout(5) { contender.value }
    assert_equal @rating_film.id, rating.rating_film_id
    assert_equal [ "Atmosphere", "  Ending!  " ], rating.reload.rating_expressions.pluck(:text)
    assert_equal Ratings::Rating::Values::PRETTY_GOOD, rating.reload.value
    assert_equal @user.id, rating_events.sole.payload["user_id"]
    assert_equal 0, Identity::CleanupExpiredAccounts.call[:guests_deleted]
  end

  test "claim winning against cleanup retains saved rating and stream identity" do
    rating = submit
    event = rating_events.sole
    expression_ids = rating.rating_expressions.pluck(:id)
    contender = nil
    Identity::User.transaction do
      @user.lock!
      claim
      travel Identity::UserGuest::EXPIRY_DURATION
      contender = blocked { Identity::CleanupExpiredAccounts.call }
    end
    assert_equal 0, Timeout.timeout(5) { contender.value }[:guests_deleted]
    assert_equal [ "Atmosphere", "  Ending!  " ], rating.reload.rating_expressions.pluck(:text)
    assert_equal Ratings::Rating::Values::PRETTY_GOOD, rating.reload.value
    assert_equal @rating_film.id, rating.rating_film_id
    assert_equal @user.id, @rating_film.reload.user_id
    assert_equal expression_ids, rating.reload.rating_expressions.pluck(:id)
    assert_equal event.id, rating_events.sole.id
    assert_equal event.domain_event_stream_id, rating_events.sole.domain_event_stream_id
  end

  def submit_selected_film
    row = Ratings::PrepareCandidate.call(user_id: @user.id, film_id: @film.id)
    Ratings::SubmitRating.call(user_id: @user.id, rating_film_id: row.id,
      value: Ratings::Rating::Values::BRILLIANT, expression_texts: [ "Selected film evidence" ])
  end

  test "competing targeted submissions admit one candidate and one first rating" do
    @rating_film.destroy!
    contender = nil
    Identity::User.transaction do
      submit_selected_film
      contender = blocked do
        submit_selected_film
      rescue Ratings::AlreadyRated
        :already_rated
      end
    end
    assert_equal :already_rated, Timeout.timeout(5) { contender.value }
    row = Ratings::RatingFilm.where(user: @user, film: @film).sole
    assert_equal [ "Selected film evidence" ], row.ratings.sole.rating_expressions.pluck(:text)
    assert_equal 1, rating_events.count
  end

  test "a targeted submission wins over a waiting queue submission" do
    assert_first_submission_wins(first: method(:submit_selected_film), second: method(:submit),
      expressions: [ "Selected film evidence" ])
  end

  test "a queue submission wins over a waiting targeted submission" do
    assert_first_submission_wins(first: method(:submit), second: method(:submit_selected_film),
      expressions: [ "Atmosphere", "  Ending!  " ])
  end

  def assert_first_submission_wins(first:, second:, expressions:)
    contender = nil
    Identity::User.transaction do
      first.call
      contender = blocked do
        second.call
      rescue Ratings::AlreadyRated
        :already_rated
      end
    end
    assert_equal :already_rated, Timeout.timeout(5) { contender.value }
    assert_equal expressions, @rating_film.ratings.sole.rating_expressions.pluck(:text)
    assert_equal 1, rating_events.count
  end

  test "targeted admission waiting across expiry leaves no candidate" do
    @rating_film.destroy!
    contender = nil
    Identity::User.transaction do
      @user.lock!
      contender = blocked do
        submit_selected_film
      rescue Ratings::IdentityUnavailable
        :inactive
      end
      travel Identity::UserGuest::EXPIRY_DURATION
    end
    assert_equal :inactive, Timeout.timeout(5) { contender.value }
    assert_empty Ratings::RatingFilm.where(user: @user)
    assert_empty rating_events
  end

  test "concurrent explicit entries return the same unfinished candidate" do
    @rating_film.destroy!
    first = contender = nil
    Identity::User.transaction do
      first = Ratings::PrepareCandidate.call(user_id: @user.id, film_id: @film.id)
      contender = blocked { Ratings::PrepareCandidate.call(user_id: @user.id, film_id: @film.id) }
    end
    assert_equal first.id, Timeout.timeout(5) { contender.value }.id
    assert_equal [ first.id ], Ratings::RatingFilm.where(user: @user, film: @film).pluck(:id)
    assert_empty first.ratings
    assert_empty rating_events
  end

  def revise(previous_rating_id:)
    Ratings::ReviseRating.call(user_id: @user.id, rating_film_id: @rating_film.id,
      previous_rating_id:, value: Ratings::Rating::Values::BRILLIANT, expression_texts: [ "Replacement evidence" ])
  end

  test "competing revisions yield one replacement and one stale failure" do
    original = submit
    contender = replacement = nil
    Identity::User.transaction do
      replacement = revise(previous_rating_id: original.id)
      contender = blocked do
        revise(previous_rating_id: original.id)
      rescue Ratings::StaleRating
        :stale
      end
    end
    assert_equal :stale, Timeout.timeout(5) { contender.value }
    assert_equal replacement.id, @rating_film.reload.current_rating.id
    assert Ratings::Rating.exists?(original.id)
    assert_equal 2, @rating_film.ratings.count
    assert_equal 1, rating_events.count
  end

  test "revision waiting across expiry rejects owner without superseding" do
    original = submit
    contender = nil
    Identity::User.transaction do
      @user.lock!
      contender = blocked do
        revise(previous_rating_id: original.id)
      rescue Ratings::IdentityUnavailable
        :inactive
      end
      travel Identity::UserGuest::EXPIRY_DURATION
    end
    assert_equal :inactive, Timeout.timeout(5) { contender.value }
    assert_equal original.id, @rating_film.reload.current_rating.id
    assert_equal 1, rating_events.count
  end

  test "claim preserves revision history and waiting replacement past guest expiry" do
    original = submit
    replacement = revise(previous_rating_id: original.id)
    contender = nil
    Identity::User.transaction do
      @user.lock!
      claim
      contender = blocked { revise(previous_rating_id: replacement.id) }
      travel Identity::UserGuest::EXPIRY_DURATION
    end
    latest = Timeout.timeout(5) { contender.value }
    assert_equal latest.id, @rating_film.reload.current_rating.id
    assert_equal 3, @rating_film.ratings.count
    assert Ratings::Rating.exists?(original.id)
    assert Ratings::Rating.exists?(replacement.id)
    assert_equal [ "Atmosphere", "  Ending!  " ], original.rating_expressions.pluck(:text)
    assert_equal [ "Replacement evidence" ], replacement.rating_expressions.pluck(:text)
    assert_equal 0, Identity::CleanupExpiredAccounts.call[:guests_deleted]
    assert_equal 1, rating_events.count
  end

  test "cleanup deletes complete revision history before a waiting revision" do
    original = submit
    replacement = revise(previous_rating_id: original.id)
    contender = nil
    travel Identity::UserGuest::EXPIRY_DURATION
    Identity::User.transaction do
      @user.lock!
      contender = blocked do
        revise(previous_rating_id: replacement.id)
      rescue Ratings::IdentityUnavailable
        :inactive
      end
      assert_equal 1, Identity::CleanupExpiredAccounts.call[:guests_deleted]
    end
    assert_equal :inactive, Timeout.timeout(5) { contender.value }
    assert_empty Ratings::Rating.where(rating_film_id: @rating_film.id)
    assert_empty Ratings::RatingExpression.where(rating_id: [ original.id, replacement.id ])
    assert_empty rating_events
    assert Registry::Film.exists?(@film.id)
  end
end
