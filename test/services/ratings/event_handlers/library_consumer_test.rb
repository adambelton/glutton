require "test_helper"

class Ratings::LibraryConsumerTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "Library activity")
    @subscription = DomainEvents::Delivery::Subscriptions.all.find { |entry| entry.name == Ratings::EventHandlers::ConsumeLibraryEvent::SUBSCRIBER }
  end

  def publish(name, **options)
    Identity::User.transaction do
      DomainEvents::Publication::Publish.call(user_id: @user.id, publisher: Library::Events::PUBLISHING_DOMAIN,
        stream_key: "film:#{@film.id}", name:, payload: { user_id: @user.id, film_id: @film.id }, **options)
    end
  end

  def dispatch
    DomainEvents::Delivery::Dispatch.call(subscriptions: [ @subscription ])
  end

  def candidate
    Ratings::RatingFilm.find_by(user: @user, film: @film)
  end

  def deliver(event)
    receipt = DomainEvents::EventDelivery.create!(domain_event: event, subscriber: @subscription.name, next_attempt_at: Time.current)
    [ DomainEvents::Delivery::Deliver.call(delivery_id: receipt.id, subscription: @subscription), receipt.reload ]
  end

  test "each admitted state preserves dismissal and original evidence across all combinations" do
    [ false, true ].product([ false, true ]).each do |suppressed, dismissed|
      @subscription.event_names.each do |name|
        @film = Registry::Film.create!(title: "State combination")
        row = Ratings::RatingFilm.create!(user: @user, film: @film, suppressed:, dismissed:)
        rating = Ratings::RatingRecording::SubmitRating.call(user_id: @user.id, rating_film_id: row.id,
          value: Ratings::Rating::Values::BRILLIANT, notes: "Original")
        created_at = row.created_at
        event = publish(name)
        assert_no_difference([ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ]) { deliver(event) }
        row.reload
        assert_equal name == Library::Events::FILM_ADDED_TO_WATCHLIST, row.suppressed?
        assert_equal dismissed, row.dismissed?
        assert_equal created_at, row.created_at
        assert_equal [ rating.id ], row.ratings.pluck(:id)
        assert_equal "Original", rating.notes
      end
    end
  end

  test "watchlist and watched events admit candidates and removal does not" do
    assert_equal :ignored, deliver(publish(Library::Events::FILM_REMOVED_FROM_WATCHLIST)).first
    assert_nil candidate
    [ [ Library::Events::FILM_MARKED_WATCHED, false, false ],
      [ Library::Events::FILM_ADDED_TO_WATCHLIST, true, false ] ].each do |name, suppressed, dismissed|
      @film = Registry::Film.create!(title: "Admission")
      assert_equal :processed, deliver(publish(name)).first
      assert_equal suppressed, candidate.suppressed?
      assert_equal dismissed, candidate.dismissed?
    end
  end

  test "suppressed films stay outside bounded queue and return at original position" do
    publish(Library::Events::FILM_ADDED_TO_WATCHLIST)
    dispatch
    first = candidate
    travel 1.hour
    later = Ratings::RatingFilm.create!(user: @user, film: Registry::Film.create!(title: "Later"))
    foreign = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film: @film)
    assert_equal [ later.id ], Ratings::CandidateSelection::NextCandidates.call(user_id: @user.id, limit: 1).map(&:id)
    publish(Library::Events::FILM_REMOVED_FROM_WATCHLIST)
    dispatch
    assert_equal [ first.id, later.id ], Ratings::CandidateSelection::NextCandidates.call(user_id: @user.id, limit: 2).map(&:id)
    first.reload.dismiss!
    publish(Library::Events::FILM_ADDED_TO_WATCHLIST)
    dispatch
    publish(Library::Events::FILM_MARKED_WATCHED)
    dispatch
    assert first.reload.dismissed?
    assert_equal [ later.id ], Ratings::CandidateSelection::NextCandidates.call(user_id: @user.id).map(&:id)
    assert_not foreign.reload.suppressed?
  end

  test "retained hold release hold history and replay respect stream order" do
    events = [ Library::Events::FILM_ADDED_TO_WATCHLIST, Library::Events::FILM_REMOVED_FROM_WATCHLIST,
      Library::Events::FILM_ADDED_TO_WATCHLIST, Library::Events::FILM_MARKED_WATCHED ].map do |name|
      event = publish(name)
      travel 1.second
      event
    end
    [ true, false, true, false ].each do |suppressed|
      assert_equal({ processed: 1 }, DomainEvents::Delivery::Dispatch.call(limit: 1, subscriptions: [ @subscription ]))
      assert_equal suppressed, candidate.suppressed?
    end
    updated_at = candidate.updated_at
    receipt = DomainEvents::EventDelivery.find_by!(domain_event: events.first, subscriber: @subscription.name)
    assert_equal :not_due, DomainEvents::Delivery::Deliver.call(delivery_id: receipt.id, subscription: @subscription)
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
    connection = Ratings::RatingFilm.connection
    connection.execute("ALTER TABLE rating_films ADD CONSTRAINT consumer_test_no_hold CHECK (NOT suppressed)")
    assert_equal({ retrying: 1 }, dispatch)
    assert_nil candidate
    connection.execute("ALTER TABLE rating_films DROP CONSTRAINT consumer_test_no_hold")
    travel 5.seconds
    assert_equal({ processed: 1 }, dispatch)
    assert candidate.suppressed?
    assert_equal({ processed: 1 }, dispatch)
    assert_not candidate.suppressed?
    assert_equal DomainEvents::EventDelivery::Statuses::PROCESSED, DomainEvents::EventDelivery.find_by!(domain_event: first).status
  ensure
    connection&.execute("ALTER TABLE rating_films DROP CONSTRAINT IF EXISTS consumer_test_no_hold")
  end

  test "bad versions and identifiers retry without writes" do
    malformed_events = [
      -> { { schema_version: 2 } },
      -> { { payload: {} } },
      -> { { payload: { user_id: @user.id + 1, film_id: @film.id } } },
      -> { { payload: { user_id: @user.id, film_id: @film.id.to_s } } },
      -> { { payload: { user_id: @user.id, film_id: @film.id + 1 } } }
    ]
    malformed_events.each do |build_options|
      @film = Registry::Film.create!(title: "Malformed Library event")
      outcome, receipt = deliver(publish(Library::Events::FILM_MARKED_WATCHED, **build_options.call))
      assert_equal :retrying, outcome
      assert_equal "ArgumentError", receipt.last_error_class
      assert_nil candidate
    end
    @film = Registry::Film.create!(title: "Removed film")
    event = publish(Library::Events::FILM_MARKED_WATCHED)
    @film.delete
    outcome, receipt = deliver(event)
    assert_equal :ignored, outcome
    assert_equal DomainEvents::EventDelivery::Statuses::IGNORED, receipt.status
  end

  test "real cross domain delivery in either order preserves rating and dismissal without loops" do
    [ true, false ].each do |library_first|
      @film = Registry::Film.create!(title: "Both domains")
      publish(Library::Events::FILM_ADDED_TO_WATCHLIST)
      dispatch if library_first
      row = candidate || Ratings::RatingFilm.create!(user: @user, film: @film)
      row.dismiss!
      rating = Ratings::RatingRecording::SubmitRating.call(user_id: @user.id, rating_film_id: row.id,
        value: Ratings::Rating::Values::BRILLIANT, notes: "Still original")
      5.times { DomainEvents::Delivery::Dispatch.call }
      assert Library::LibraryFilm.exists?(watched: true, user: @user, film: @film)
      assert row.reload.dismissed?
      assert_not row.suppressed?
      assert_equal "Still original", rating.notes
      assert_not_includes Ratings::CandidateSelection::NextCandidates.call(user_id: @user.id, limit: 100).map(&:id), row.id
      assert_no_difference "DomainEvents::DomainEvent.count" do
        assert_empty DomainEvents::Delivery::Dispatch.call
      end
    end
  end
end
