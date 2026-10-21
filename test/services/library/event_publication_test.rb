require "test_helper"

class Library::EventPublicationTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @user = UserGuest.create!
    @film = Film.create!(title: "Published film")
  end

  def act(operation, user: @user, film: @film)
    operation.call(user_id: user.id, film_id: film.id)
  end

  def events(user: @user, film: @film)
    DomainEvent.joins(:domain_event_stream).where(domain_event_streams: {
      user_id: user.id, publisher: Library::EVENTS_PUBLISHING_DOMAIN, stream_key: "film:#{film.id}"
    }).order(:sequence)
  end

  test "creation transition and removal facts have the immutable v1 contract" do
    entry = act(Library::MarkNotInterested)
    assert_equal entry.id, act(Library::AddToWatchlist).id
    assert_equal entry.id, act(Library::MarkNotInterested).id
    assert act(Library::RemoveNotInterested).destroyed?
    recreated = act(Library::AddToWatchlist)
    assert_not_equal entry.id, recreated.id
    assert act(Library::RemoveFromWatchlist).destroyed?
    act(Library::AddToWatchlist)
    watched = act(Library::RecordWatched)
    assert watched.persisted?
    assert_equal [ Library::Events::FILM_MARKED_NOT_INTERESTED, Library::Events::FILM_ADDED_TO_WATCHLIST, Library::Events::FILM_MARKED_NOT_INTERESTED,
      Library::Events::FILM_DISMISSAL_REMOVED, Library::Events::FILM_ADDED_TO_WATCHLIST, Library::Events::FILM_REMOVED_FROM_WATCHLIST, Library::Events::FILM_ADDED_TO_WATCHLIST,
      Library::Events::FILM_MARKED_WATCHED ], events.pluck(:name)
    classifications = [ "not_interested", "to_watch", "not_interested", nil, "to_watch", nil, "to_watch", "watched" ]
    events.each_with_index do |event, index|
      assert_equal({ "user_id" => @user.id, "film_id" => @film.id, "classification" => classifications[index] }, event.payload)
      assert_equal index + 1, event.sequence
      assert_equal 1, event.schema_version
      assert_equal Time.current, event.occurred_at
      assert_equal event.id, event.correlation_id
      assert_nil event.causation_id
    end
    assert_equal 1, events.pluck(:domain_event_stream_id).uniq.size
  end

  test "direct watched creation and independent owners and films start independent sequences" do
    act(Library::RecordWatched)
    other = UserGuest.create!
    second = Film.create!(title: "Second")
    act(Library::RecordWatched, user: other)
    act(Library::RecordWatched, film: second)
    [ events, events(user: other), events(film: second) ].each do |stream_events|
      assert_equal [ 1 ], stream_events.pluck(:sequence)
      assert_equal [ Library::Events::FILM_MARKED_WATCHED ], stream_events.pluck(:name)
    end
  end

  test "invalid and duplicate operations publish no events" do
    [ [ LibraryFilmWatched, Library::RecordWatched, Library::AlreadyWatched ],
      [ LibraryFilmNotInterested, Library::RecordWatched, Library::AlreadyWatched ],
      [ LibraryFilmToWatch, Library::AddToWatchlist, Library::WatchlistUnavailable ],
      [ LibraryFilmWatched, Library::AddToWatchlist, Library::WatchlistUnavailable ],
      [ LibraryFilmNotInterested, Library::MarkNotInterested, Library::DismissalUnavailable ],
      [ LibraryFilmWatched, Library::MarkNotInterested, Library::DismissalUnavailable ],
      [ LibraryFilmWatched, Library::RemoveFromWatchlist, Library::NotOnWatchlist ],
      [ LibraryFilmToWatch, Library::RemoveNotInterested, Library::NotMarkedNotInterested ] ].each do |model, operation, error|
      film = Film.create!(title: "Rejected")
      model.create!(user: @user, film:)
      assert_no_difference "DomainEvent.count" do
        assert_raises(error) { act(operation, film:) }
      end
    end
    assert_equal 0, DomainEventStream.count
    assert_no_difference "DomainEvent.count" do
      assert_raises(Library::NotOnWatchlist) { act(Library::RemoveFromWatchlist) }
      assert_raises(Library::NotMarkedNotInterested) { act(Library::RemoveNotInterested) }
      assert_raises(Library::FilmUnavailable) { Library::AddToWatchlist.call(user_id: @user.id, film_id: nil) }
      travel UserGuest::EXPIRY_DURATION do
        assert_raises(Library::IdentityUnavailable) { act(Library::AddToWatchlist) }
      end
    end
  end

  test "publication failure rolls back creation transition removal and sequence even when caller rescues" do
    [ [ nil, Library::RecordWatched ], [ LibraryFilmNotInterested, Library::AddToWatchlist ],
      [ LibraryFilmToWatch, Library::RemoveFromWatchlist ] ].each do |model, operation|
      film = Film.create!(title: "Rollback")
      original = model&.create!(user: @user, film:)
      callback = -> { raise "injected publication failure" }
      DomainEvent.set_callback(:create, :after, callback)
      begin
        LibraryFilm.transaction(requires_new: true) do
          assert_raises(RuntimeError) { act(operation, film:) }
          assert_empty events(film:)
          assert_not DomainEventStream.exists?(user: @user, stream_key: "film:#{film.id}")
          if original
            restored = LibraryFilm.find(original.id)
            assert_equal original.can_watch?, restored.can_watch?
            assert_equal original.can_add_to_watchlist?, restored.can_add_to_watchlist?
          else
            assert_not LibraryFilm.exists?(user: @user, film:)
          end
        end
      ensure
        DomainEvent.skip_callback(:create, :after, callback)
      end
      act(operation, film:)
      assert_equal 1, events(film:).first.sequence
    end
  end

  test "outer rollback restores source and existing stream sequence for creation transition and removal" do
    [ Library::AddToWatchlist, Library::RecordWatched, Library::RemoveFromWatchlist ].each do |operation|
      film = Film.create!(title: "Outer rollback")
      original = act(Library::AddToWatchlist, film:) unless operation == Library::AddToWatchlist
      LibraryFilm.transaction(requires_new: true) do
        act(operation, film:)
        raise ActiveRecord::Rollback
      end
      if original
        assert LibraryFilm.find(original.id).can_watch?
        assert_equal [ 1 ], events(film:).pluck(:sequence)
        assert_equal 1, events(film:).first.domain_event_stream.sequence
      else
        assert_empty events(film:)
        assert_not LibraryFilm.exists?(user: @user, film:)
      end
      act(operation, film:)
      assert_equal original ? [ 1, 2 ] : [ 1 ], events(film:).pluck(:sequence)
    end
  end
end
