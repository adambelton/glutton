require "test_helper"

class Library::EventPublicationTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @user = UserGuest.create!
    @film = Film.create!(title: "Published film")
    @entry = LibraryFilmToWatch.create!(user: @user, film: @film)
  end

  def act(operation)
    operation.call(user_id: @user.id, library_film_id: @entry.id)
  end

  def events
    DomainEvent.joins(:domain_event_stream).where(domain_event_streams: {
      user_id: @user.id, publisher: Library::EVENTS_PUBLISHING_DOMAIN, stream_key: "film:#{@film.id}"
    }).order(:sequence)
  end

  test "transition and removal facts retain minimal v1 payload and continuous stream sequence" do
    original = @entry
    act(Library::MarkNotInterested)
    act(Library::AddToWatchlist)
    act(Library::MarkNotInterested)
    assert act(Library::RemoveNotInterested).destroyed?
    @entry = LibraryFilmToWatch.create!(user: @user, film: @film)
    assert_not_equal original.id, @entry.id
    assert act(Library::RemoveFromWatchlist).destroyed?
    @entry = LibraryFilmToWatch.create!(user: @user, film: @film)
    act(Library::RecordWatched)
    assert_equal [ Library::Events::FILM_MARKED_NOT_INTERESTED, Library::Events::FILM_ADDED_TO_WATCHLIST,
      Library::Events::FILM_MARKED_NOT_INTERESTED, Library::Events::FILM_DISMISSAL_REMOVED,
      Library::Events::FILM_REMOVED_FROM_WATCHLIST, Library::Events::FILM_MARKED_WATCHED ], events.pluck(:name)
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

  test "outer rollback restores the entry and existing stream sequence" do
    act(Library::MarkNotInterested)
    LibraryFilm.transaction(requires_new: true) do
      act(Library::AddToWatchlist)
      raise ActiveRecord::Rollback
    end
    assert LibraryFilm.find(@entry.id).can_add_to_watchlist?
    assert_equal [ 1 ], events.pluck(:sequence)
    assert_equal 1, events.first.domain_event_stream.sequence
    act(Library::AddToWatchlist)
    assert_equal [ 1, 2 ], events.pluck(:sequence)
  end

  test "independent owners and films keep independent event streams" do
    entries = [ @entry,
      LibraryFilmToWatch.create!(user: UserGuest.create!, film: @film),
      LibraryFilmToWatch.create!(user: @user, film: Film.create!(title: "Other")) ]
    entries.each { |entry| Library::RecordWatched.call(user_id: entry.user_id, library_film_id: entry.id) }
    assert_equal [ 1, 1, 1 ], DomainEvent.pluck(:sequence)
    assert_equal 3, DomainEvent.distinct.count(:domain_event_stream_id)
  end
end
