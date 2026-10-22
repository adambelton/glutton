require "test_helper"

class Library::RatingConsumerTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @user = UserGuest.create!
    @film = Film.create!(title: "Rated film")
    @subscription = DomainEvents::Subscriptions.all.find { |entry| entry.name == Library::ConsumeRatingsEvent::SUBSCRIBER }
  end

  def publish(payload: { user_id: @user.id, film_id: @film.id }, **options)
    User.transaction do
      DomainEvents::Publish.call(user_id: @user.id, publisher: Ratings::EVENTS_PUBLISHING_DOMAIN,
        stream_key: "film:#{@film.id}", name: Ratings::Events::RATING_SUBMITTED, payload:, **options)
    end
  end

  def dispatch(**options)
    DomainEvents::Dispatch.call(subscriptions: [ @subscription ], **options)
  end

  def derived
    DomainEvent.where(name: Library::Events::FILM_MARKED_WATCHED)
  end

  def receipt(event)
    EventDelivery.find_by!(subscriber: @subscription.name, domain_event_id: event.id)
  end

  test "retained rating creates watched with exact causal event and preserves original evidence" do
    candidate = RatingFilm.create!(user: @user, film: @film)
    rating = Ratings::SubmitRating.call(user_id: @user.id, rating_film_id: candidate.id,
      value: Rating::Values::BRILLIANT, expression_texts: [ "Atmosphere" ])
    source = DomainEvent.find_by!(name: Ratings::Events::RATING_SUBMITTED)
    assert_equal 1, DomainEvents::Status.call(subscriptions: [ @subscription ])[:undiscovered].sole[:count]
    assert_no_difference [ "Rating.count", "RatingExpression.count" ] do
      assert_equal({ processed: 1 }, dispatch)
    end
    assert_equal [ "Atmosphere" ], rating.reload.rating_expressions.pluck(:text)
    assert_equal Rating::Values::BRILLIANT, rating.value
    assert LibraryFilmWatched.exists?(user: @user, film: @film)
    event = derived.sole
    assert_equal({ "user_id" => @user.id, "film_id" => @film.id }, event.payload)
    assert_equal 1, event.schema_version
    assert_equal source.id, event.causation_id
    assert_equal source.correlation_id, event.correlation_id
    assert_equal EventDelivery::Statuses::PROCESSED, receipt(source).status
    assert_empty dispatch
    assert_equal 1, derived.count
  end

  test "watchlist and not interested are reconciled preserving identity and public failures" do
    [ Library::AddToWatchlist, Library::MarkNotInterested ].each do |operation|
      @film = Film.create!(title: "Intent")
      entry = operation.call(user_id: @user.id, film_id: @film.id)
      publish
      assert_equal({ processed: 1 }, dispatch)
      watched = LibraryFilmWatched.find_by!(user: @user, film: @film)
      assert_equal entry.id, watched.id
      assert_equal entry.created_at, watched.created_at
      assert_raises(Library::AlreadyWatched) { Library::RecordWatched.call(user_id: @user.id, film_id: @film.id) }
      assert_raises(Library::WatchlistUnavailable) { Library::AddToWatchlist.call(user_id: @user.id, film_id: @film.id) }
      assert_raises(Library::DismissalUnavailable) { Library::MarkNotInterested.call(user_id: @user.id, film_id: @film.id) }
    end
  end

  test "already watched and repeated viewing evidence are ignored without timestamp or event changes" do
    entry = Library::RecordWatched.call(user_id: @user.id, film_id: @film.id)
    updated_at = entry.updated_at
    travel 1.hour
    event = publish
    assert_no_difference "DomainEvent.count" do
      assert_equal({ ignored: 1 }, dispatch)
      assert_equal :not_due, DomainEvents::Deliver.call(delivery_id: receipt(event).id, subscription: @subscription)
    end
    publish
    assert_equal({ ignored: 1 }, dispatch)
    assert_equal updated_at, entry.reload.updated_at
    assert_equal 1, derived.count
  end

  test "publication failure rolls back transition and receipt then retry commits once" do
    entry = Library::MarkNotInterested.call(user_id: @user.id, film_id: @film.id)
    event = publish
    connection = DomainEvent.connection
    connection.execute("ALTER TABLE domain_events ADD CONSTRAINT consumer_test_block_watched CHECK (name <> 'FilmMarkedWatched')")
    assert_equal({ retrying: 1 }, dispatch)
    assert LibraryFilmNotInterested.exists?(entry.id)
    assert_empty derived
    assert_equal EventDelivery::Statuses::PENDING, receipt(event).status
    assert_nil receipt(event).completed_at
    connection.execute("ALTER TABLE domain_events DROP CONSTRAINT consumer_test_block_watched")
    travel 5.seconds
    assert_equal({ processed: 1 }, dispatch)
    assert LibraryFilmWatched.exists?(entry.id)
    assert_equal 1, derived.count
  ensure
    connection&.execute("ALTER TABLE domain_events DROP CONSTRAINT IF EXISTS consumer_test_block_watched")
  end

  test "invalid contracts retry and reach terminal failure without acknowledging success" do
    event = publish(schema_version: 2)
    EventDelivery::MAX_ATTEMPTS.times do
      assert_no_difference "LibraryFilm.count" do
        dispatch
      end
      travel 5.minutes
    end
    assert_equal EventDelivery::Statuses::FAILED, receipt(event).status
    assert_equal "ArgumentError", receipt(event).last_error_class
    assert_empty derived
  end

  test "malformed identities and stream mismatches never create Library state" do
    valid = { user_id: @user.id, film_id: @film.id }
    [ {}, valid.merge(user_id: @user.id + 1), valid.merge(film_id: @film.id.to_s),
      valid.merge(film_id: @film.id + 1), valid.merge(film_id: nil), valid.merge(film_id: -1) ].each do |payload|
      event = publish(payload:)
      delivery = EventDelivery.create!(subscriber: @subscription.name, domain_event: event, next_attempt_at: Time.current)
      assert_equal :retrying, DomainEvents::Deliver.call(delivery_id: delivery.id, subscription: @subscription)
      assert_equal "ArgumentError", delivery.reload.last_error_class
      # Clear the failed predecessor for the next independent malformed-contract case.
      delivery.complete!(:skipped)
    end
    assert_empty LibraryFilm.where(user: @user)
  end

  test "rating specific fields are not interpreted by Library" do
    [ {}, { value: nil }, { value: "opaque rating choice", rating_id: nil, extra: "opaque metadata" } ].each do |fields|
      @film = Film.create!(title: "Viewing evidence")
      publish(payload: { user_id: @user.id, film_id: @film.id }.merge(fields))
      assert_equal({ processed: 1 }, dispatch)
      assert LibraryFilmWatched.exists?(user: @user, film: @film)
    end
  end

  test "missing film fails without recreating catalogue data" do
    event = publish
    @film.delete
    assert_equal({ retrying: 1 }, dispatch)
    assert_equal "Library::FilmUnavailable", receipt(event).last_error_class
    assert_empty LibraryFilm.where(user: @user)
  end

  test "bounded catch up filters publisher and name and observes stream order" do
    first = publish
    travel 1.second
    second = publish
    travel 1.second
    publish(name: "Unsubscribed")
    publish(publisher: "unsubscribed")
    assert_equal({ processed: 1 }, dispatch(limit: 1))
    assert_equal EventDelivery::Statuses::PROCESSED, receipt(first).status
    assert_equal({ ignored: 1 }, dispatch(limit: 1))
    assert_equal EventDelivery::Statuses::IGNORED, receipt(second).status
    assert_empty dispatch(limit: 1)
    assert_equal 2, EventDelivery.where(subscriber: @subscription.name).count
    assert_equal 1, derived.count
  end

  test "expired and deleted identities are skipped" do
    event = publish
    travel UserGuest::EXPIRY_DURATION
    assert_equal({ skipped: 1 }, dispatch)
    assert_equal EventDelivery::Statuses::SKIPPED, receipt(event).status
    @user = UserGuest.create!
    event = publish
    @user.becomes!(UserDeleted).save!
    assert_equal({ skipped: 1 }, dispatch)
    assert_equal EventDelivery::Statuses::SKIPPED, receipt(event).status
    assert_empty LibraryFilm.all
  end
end
