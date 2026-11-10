require "test_helper"

class Library::RatingConsumerTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "Rated film")
    @subscription = DomainEvents::Delivery::Subscriptions.all.find { |entry| entry.name == Library::EventHandlers::ConsumeRatingsEvent::SUBSCRIBER }
  end

  def publish(payload: { user_id: @user.id, film_id: @film.id }, **options)
    Identity::User.transaction do
      DomainEvents::Publication::Publish.call(user_id: @user.id, publisher: Ratings::Events::PUBLISHING_DOMAIN,
        stream_key: "film:#{@film.id}", name: Ratings::Events::RATING_SUBMITTED, payload:, **options)
    end
  end

  def dispatch(**options)
    DomainEvents::Delivery::Dispatch.call(subscriptions: [ @subscription ], **options)
  end

  def derived
    DomainEvents::DomainEvent.where(name: Library::Events::FILM_MARKED_WATCHED)
  end

  def receipt(event)
    DomainEvents::EventDelivery.find_by!(subscriber: @subscription.name, domain_event_id: event.id)
  end

  test "retained rating creates watched with exact causal event and preserves original evidence" do
    candidate = Ratings::RatingFilm.create!(user: @user, film: @film)
    rating = Ratings::RatingRecording::SubmitRating.call(user_id: @user.id, rating_film_id: candidate.id,
      value: Ratings::Rating::Values::BRILLIANT, notes: "Atmosphere")
    source = DomainEvents::DomainEvent.find_by!(name: Ratings::Events::RATING_SUBMITTED)
    assert_equal 1, DomainEvents::Delivery::Status.call(subscriptions: [ @subscription ])[:undiscovered].sole[:count]
    assert_no_difference "Ratings::Rating.count" do
      assert_equal({ processed: 1 }, dispatch)
    end
    assert_equal "Atmosphere", rating.reload.notes
    assert_equal Ratings::Rating::Values::BRILLIANT, rating.value
    assert Library::LibraryFilmWatched.exists?(user: @user, film: @film)
    event = derived.sole
    assert_equal({ "user_id" => @user.id, "film_id" => @film.id }, event.payload)
    assert_equal 1, event.schema_version
    assert_equal source.id, event.causation_id
    assert_equal source.correlation_id, event.correlation_id
    assert_equal DomainEvents::EventDelivery::Statuses::PROCESSED, receipt(source).status
    assert_empty dispatch
    assert_equal 1, derived.count
  end

  test "watchlist and not interested are reconciled preserving identity and public failures" do
    [ Library::LibraryFilmToWatch, Library::LibraryFilmNotInterested ].each do |model|
      @film = Registry::Film.create!(title: "Intent")
      entry = model.create!(user: @user, film: @film)
      publish
      assert_equal({ processed: 1 }, dispatch)
      watched = Library::LibraryFilmWatched.find_by!(user: @user, film: @film)
      assert_equal entry.id, watched.id
      assert_equal entry.created_at, watched.created_at
      assert_raises(Library::Errors::AlreadyWatched) { Library::CollectionManagement::RecordWatched.call(user_id: @user.id, library_film_id: entry.id) }
      assert_raises(Library::Errors::WatchlistUnavailable) { Library::CollectionManagement::AddToWatchlist.call(user_id: @user.id, library_film_id: entry.id) }
      assert_raises(Library::Errors::DismissalUnavailable) { Library::CollectionManagement::MarkNotInterested.call(user_id: @user.id, library_film_id: entry.id) }
    end
  end

  test "already watched and repeated viewing evidence are ignored without timestamp or event changes" do
    entry = Library::LibraryFilmToWatch.create!(user: @user, film: @film)
    entry = Library::CollectionManagement::RecordWatched.call(user_id: @user.id, library_film_id: entry.id)
    updated_at = entry.updated_at
    travel 1.hour
    event = publish
    assert_no_difference "DomainEvents::DomainEvent.count" do
      assert_equal({ ignored: 1 }, dispatch)
      assert_equal :not_due, DomainEvents::Delivery::Deliver.call(delivery_id: receipt(event).id, subscription: @subscription)
    end
    publish
    assert_equal({ ignored: 1 }, dispatch)
    assert_equal updated_at, entry.reload.updated_at
    assert_equal 1, derived.count
  end

  test "publication failure rolls back transition and receipt then retry commits once" do
    entry = Library::LibraryFilmNotInterested.create!(user: @user, film: @film)
    event = publish
    connection = DomainEvents::DomainEvent.connection
    connection.execute("ALTER TABLE domain_events ADD CONSTRAINT consumer_test_block_watched CHECK (name <> 'FilmMarkedWatched')")
    assert_equal({ retrying: 1 }, dispatch)
    assert Library::LibraryFilmNotInterested.exists?(entry.id)
    assert_empty derived
    assert_equal DomainEvents::EventDelivery::Statuses::PENDING, receipt(event).status
    assert_nil receipt(event).completed_at
    connection.execute("ALTER TABLE domain_events DROP CONSTRAINT consumer_test_block_watched")
    travel 5.seconds
    assert_equal({ processed: 1 }, dispatch)
    assert Library::LibraryFilmWatched.exists?(entry.id)
    assert_equal 1, derived.count
  ensure
    connection&.execute("ALTER TABLE domain_events DROP CONSTRAINT IF EXISTS consumer_test_block_watched")
  end

  test "invalid contracts retry and reach terminal failure without acknowledging success" do
    event = publish(schema_version: 2)
    DomainEvents::EventDelivery::MAX_ATTEMPTS.times do
      assert_no_difference "Library::LibraryFilm.count" do
        dispatch
      end
      travel 5.minutes
    end
    assert_equal DomainEvents::EventDelivery::Statuses::FAILED, receipt(event).status
    assert_equal "ArgumentError", receipt(event).last_error_class
    assert_empty derived
  end

  test "malformed identities and stream mismatches never create Library state" do
    payloads = [
      ->(_) { {} },
      ->(valid) { valid.merge(user_id: @user.id + 1) },
      ->(valid) { valid.merge(film_id: @film.id.to_s) },
      ->(valid) { valid.merge(film_id: @film.id + 1) },
      ->(valid) { valid.merge(film_id: nil) },
      ->(valid) { valid.merge(film_id: -1) }
    ]
    payloads.each do |build_payload|
      @film = Registry::Film.create!(title: "Malformed rating event")
      payload = build_payload.call(user_id: @user.id, film_id: @film.id)
      event = publish(payload:)
      delivery = DomainEvents::EventDelivery.create!(subscriber: @subscription.name, domain_event: event, next_attempt_at: Time.current)
      assert_equal :retrying, DomainEvents::Delivery::Deliver.call(delivery_id: delivery.id, subscription: @subscription)
      assert_equal "ArgumentError", delivery.reload.last_error_class
    end
    assert_empty Library::LibraryFilm.where(user: @user)
  end

  test "rating specific fields are not interpreted by Library" do
    [ {}, { value: nil }, { value: "opaque rating choice", rating_id: nil, extra: "opaque metadata" } ].each do |fields|
      @film = Registry::Film.create!(title: "Viewing evidence")
      publish(payload: { user_id: @user.id, film_id: @film.id }.merge(fields))
      assert_equal({ processed: 1 }, dispatch)
      assert Library::LibraryFilmWatched.exists?(user: @user, film: @film)
    end
  end

  test "missing film fails without recreating catalogue data" do
    event = publish
    @film.delete
    assert_equal({ retrying: 1 }, dispatch)
    assert_equal "Library::Errors::FilmUnavailable", receipt(event).last_error_class
    assert_empty Library::LibraryFilm.where(user: @user)
  end

  test "bounded catch up filters publisher and name and observes stream order" do
    first = publish
    travel 1.second
    second = publish
    travel 1.second
    publish(name: "Unsubscribed")
    publish(publisher: "unsubscribed")
    assert_equal({ processed: 1 }, dispatch(limit: 1))
    assert_equal DomainEvents::EventDelivery::Statuses::PROCESSED, receipt(first).status
    assert_equal({ ignored: 1 }, dispatch(limit: 1))
    assert_equal DomainEvents::EventDelivery::Statuses::IGNORED, receipt(second).status
    assert_empty dispatch(limit: 1)
    assert_equal 2, DomainEvents::EventDelivery.where(subscriber: @subscription.name).count
    assert_equal 1, derived.count
  end

  test "expired and deleted identities are skipped" do
    event = publish
    travel Identity::UserGuest::EXPIRY_DURATION
    assert_equal({ skipped: 1 }, dispatch)
    assert_equal DomainEvents::EventDelivery::Statuses::SKIPPED, receipt(event).status
    @user = Identity::UserGuest.create!
    event = publish
    # Simulate a deleted owner with an existing event until Identity implements this transition.
    @user.update_columns(type: "UserDeleted")
    assert_equal({ skipped: 1 }, dispatch)
    assert_equal DomainEvents::EventDelivery::Statuses::SKIPPED, receipt(event).status
    assert_empty Library::LibraryFilm.all
  end
end
