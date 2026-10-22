require "test_helper"

class Ratings::LibraryConsumerTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @user = UserGuest.create!
    @film = Film.create!(title: "Library activity")
    @subscription = DomainEvents::Subscriptions.all.find { |entry| entry.name == Ratings::ConsumeLibraryEvent::SUBSCRIBER }
  end

  def publish(name, **options)
    User.transaction do
      DomainEvents::Publish.call(user_id: @user.id, publisher: Library::EVENTS_PUBLISHING_DOMAIN,
        stream_key: "film:#{@film.id}", name:, payload: { user_id: @user.id, film_id: @film.id }, **options)
    end
  end

  def dispatch
    DomainEvents::Dispatch.call(subscriptions: [ @subscription ])
  end

  def candidate
    RatingFilm.find_by(user: @user, film: @film)
  end

  def deliver(event)
    receipt = EventDelivery.create!(domain_event: event, subscriber: @subscription.name, next_attempt_at: Time.current)
    [ DomainEvents::Deliver.call(delivery_id: receipt.id, subscription: @subscription), receipt.reload ]
  end

  test "each admitted state preserves dismissal and original evidence across all combinations" do
    [ false, true ].product([ false, true ]).each do |held, dismissed|
      Ratings::ConsumeLibraryEvent::EVENT_NAMES.each do |name|
        @film = Film.create!(title: "State combination")
        row = RatingFilm.create!(user: @user, film: @film, held:, dismissed:)
        rating = Ratings::SubmitRating.call(user_id: @user.id, rating_film_id: row.id,
          value: Rating::Values::BRILLIANT, expression_texts: [ "Original" ])
        created_at = row.created_at
        event = publish(name)
        assert_no_difference([ "Rating.count", "RatingExpression.count", "DomainEvent.count" ]) { deliver(event) }
        row.reload
        assert_equal name == Library::Events::FILM_ADDED_TO_WATCHLIST, row.held?
        assert_equal dismissed || name == Library::Events::FILM_MARKED_NOT_INTERESTED, row.dismissed?
        assert_equal created_at, row.created_at
        assert_equal [ rating.id ], row.ratings.pluck(:id)
        assert_equal [ "Original" ], rating.rating_expressions.pluck(:text)
      end
    end
  end

  test "absent rows are admitted held or dismissed and removal does not admit" do
    assert_equal :ignored, deliver(publish(Library::Events::FILM_REMOVED_FROM_WATCHLIST)).first
    assert_nil candidate
    publish(Library::Events::FILM_DISMISSAL_REMOVED)
    assert_empty dispatch
    assert_nil candidate
    [ [ Library::Events::FILM_MARKED_WATCHED, false, false ],
      [ Library::Events::FILM_ADDED_TO_WATCHLIST, true, false ],
      [ Library::Events::FILM_MARKED_NOT_INTERESTED, false, true ] ].each do |name, held, dismissed|
      @film = Film.create!(title: "Admission")
      assert_equal :processed, deliver(publish(name)).first
      assert_equal held, candidate.held?
      assert_equal dismissed, candidate.dismissed?
    end
  end

  test "held films stay outside bounded queue and return at original position" do
    publish(Library::Events::FILM_ADDED_TO_WATCHLIST)
    dispatch
    first = candidate
    travel 1.hour
    later = RatingFilm.create!(user: @user, film: Film.create!(title: "Later"))
    foreign = RatingFilm.create!(user: UserGuest.create!, film: @film)
    assert_equal [ later.id ], Ratings::NextCandidates.call(user_id: @user.id, limit: 1).map(&:id)
    publish(Library::Events::FILM_REMOVED_FROM_WATCHLIST)
    dispatch
    assert_equal [ first.id, later.id ], Ratings::NextCandidates.call(user_id: @user.id).map(&:id)
    first.reload.dismiss!
    publish(Library::Events::FILM_ADDED_TO_WATCHLIST)
    dispatch
    publish(Library::Events::FILM_MARKED_WATCHED)
    dispatch
    assert first.reload.dismissed?
    assert_equal [ later.id ], Ratings::NextCandidates.call(user_id: @user.id).map(&:id)
    assert_not foreign.reload.held?
  end

  test "retained hold release hold history and replay respect stream order" do
    events = [ Library::Events::FILM_ADDED_TO_WATCHLIST, Library::Events::FILM_REMOVED_FROM_WATCHLIST,
      Library::Events::FILM_ADDED_TO_WATCHLIST, Library::Events::FILM_MARKED_WATCHED ].map do |name|
      event = publish(name)
      travel 1.second
      event
    end
    [ true, false, true, false ].each do |held|
      assert_equal({ processed: 1 }, DomainEvents::Dispatch.call(limit: 1, subscriptions: [ @subscription ]))
      assert_equal held, candidate.held?
    end
    updated_at = candidate.updated_at
    receipt = EventDelivery.find_by!(domain_event: events.first, subscriber: @subscription.name)
    assert_equal :not_due, DomainEvents::Deliver.call(delivery_id: receipt.id, subscription: @subscription)
    assert_empty dispatch
    assert_equal updated_at, candidate.updated_at
    travel 1.hour
    assert_equal :ignored, deliver(publish(Library::Events::FILM_MARKED_WATCHED)).first
    assert_equal updated_at, candidate.updated_at
  end

  test "failed admission blocks release and retry leaves no partial row" do
    first = publish(Library::Events::FILM_ADDED_TO_WATCHLIST)
    travel 1.second
    publish(Library::Events::FILM_REMOVED_FROM_WATCHLIST)
    connection = RatingFilm.connection
    connection.execute("ALTER TABLE rating_films ADD CONSTRAINT consumer_test_no_hold CHECK (NOT held)")
    assert_equal({ retrying: 1 }, dispatch)
    assert_nil candidate
    connection.execute("ALTER TABLE rating_films DROP CONSTRAINT consumer_test_no_hold")
    travel 5.seconds
    assert_equal({ processed: 1 }, dispatch)
    assert candidate.held?
    assert_equal({ processed: 1 }, dispatch)
    assert_not candidate.held?
    assert_equal EventDelivery::Statuses::PROCESSED, EventDelivery.find_by!(domain_event: first).status
  ensure
    connection&.execute("ALTER TABLE rating_films DROP CONSTRAINT IF EXISTS consumer_test_no_hold")
  end

  test "failed combined dismissal and release rolls both back" do
    row = RatingFilm.create!(user: @user, film: @film, held: true)
    connection = RatingFilm.connection
    connection.execute("ALTER TABLE rating_films ADD CONSTRAINT consumer_test_keep_hold CHECK (held)")
    event = publish(Library::Events::FILM_MARKED_NOT_INTERESTED)
    assert_equal :retrying, deliver(event).first
    assert row.reload.held?
    assert_not row.dismissed?
    connection.execute("ALTER TABLE rating_films DROP CONSTRAINT consumer_test_keep_hold")
    travel 5.seconds
    assert_equal({ processed: 1 }, dispatch)
    assert row.reload.dismissed?
    assert_not row.held?
  ensure
    connection&.execute("ALTER TABLE rating_films DROP CONSTRAINT IF EXISTS consumer_test_keep_hold")
  end

  test "bad versions and identifiers retry without writes" do
    [ { schema_version: 2 }, { payload: {} }, { payload: { user_id: @user.id + 1, film_id: @film.id } },
      { payload: { user_id: @user.id, film_id: @film.id.to_s } },
      { payload: { user_id: @user.id, film_id: @film.id + 1 } } ].each do |options|
      outcome, receipt = deliver(publish(Library::Events::FILM_MARKED_WATCHED, **options))
      assert_equal :retrying, outcome
      assert_nil candidate
      receipt.complete!(:skipped)
    end
    event = publish(Library::Events::FILM_MARKED_WATCHED)
    @film.delete
    outcome, receipt = deliver(event)
    assert_equal :retrying, outcome
    assert_equal "Ratings::FilmUnavailable", receipt.last_error_class
  end

  test "real cross domain delivery in either order preserves rating and dismissal without loops" do
    [ true, false ].each do |library_first|
      @film = Film.create!(title: "Both domains")
      Library::AddToWatchlist.call(user_id: @user.id, film_id: @film.id)
      Library::MarkNotInterested.call(user_id: @user.id, film_id: @film.id)
      2.times { dispatch } if library_first
      row = candidate || RatingFilm.create!(user: @user, film: @film)
      rating = Ratings::SubmitRating.call(user_id: @user.id, rating_film_id: row.id,
        value: Rating::Values::BRILLIANT, expression_texts: [ "Still original" ])
      5.times { DomainEvents::Dispatch.call }
      assert LibraryFilmWatched.exists?(user: @user, film: @film)
      assert row.reload.dismissed?
      assert_not row.held?
      assert_equal [ "Still original" ], rating.rating_expressions.pluck(:text)
      assert_empty Ratings::NextCandidates.call(user_id: @user.id)
      assert_no_difference "DomainEvent.count" do
        assert_empty DomainEvents::Dispatch.call
      end
    end
  end
end
