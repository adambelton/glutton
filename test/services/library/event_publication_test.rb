require "test_helper"

class Library::EventPublicationTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "Published film")
    @entry = Library::LibraryFilm.create!(user: @user, film: @film)
  end

  def act(operation)
    operation.call(user_id: @user.id, library_film_id: @entry.id)
  end

  def events
    DomainEvents::DomainEvent.joins(:domain_event_stream).where(domain_event_streams: {
      user_id: @user.id, publisher: Library::Events::PUBLISHING_DOMAIN, stream_key: "film:#{@film.id}"
    }).order(:sequence)
  end

  test "transition and removal facts retain minimal v1 payload and continuous stream sequence" do
    original = @entry
    assert act(Library::CollectionManagement::RemoveFromWatchlist).destroyed?
    @entry = Library::LibraryFilm.create!(user: @user, film: @film)
    act(Library::CollectionManagement::MoveWatchlistToWatched)
    assert_not_equal original.id, @entry.id
    assert_equal [ Library::Events::FILM_REMOVED_FROM_WATCHLIST, Library::Events::FILM_MARKED_WATCHED ], events.pluck(:name)
    events.each_with_index do |event, index|
      assert_equal({ "user_id" => @user.id, "film_id" => @film.id }, event.payload)
      assert_equal index + 1, event.sequence
      assert_equal 1, event.schema_version
      assert_equal Time.current, event.occurred_at
      assert_equal event.id, event.correlation_id
      assert_nil event.causation_id
    end
    assert_equal 1, events.pluck(:domain_event_stream_id).uniq.size
  end

  test "independent owners and films keep independent event streams" do
    entries = [ @entry,
      Library::LibraryFilm.create!(user: Identity::UserGuest.create!, film: @film),
      Library::LibraryFilm.create!(user: @user, film: Registry::Film.create!(title: "Other")) ]
    entries.each { |entry| Library::CollectionManagement::MoveWatchlistToWatched.call(user_id: entry.user_id, library_film_id: entry.id) }
    assert_equal [ 1, 1, 1 ], DomainEvents::DomainEvent.pluck(:sequence)
    assert_equal 3, DomainEvents::DomainEvent.distinct.count(:domain_event_stream_id)
  end
end
