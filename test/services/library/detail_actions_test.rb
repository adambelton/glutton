require "test_helper"

class Library::DetailActionsTest < ActiveSupport::TestCase
  setup do
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "Detail film")
    @entry = Library::LibraryFilmToWatch.create!(user: @user, film: @film)
  end

  test "missing and inactive owners and foreign entries cannot be used" do
    [ Library::FindFilm, Library::RecordWatched, Library::RemoveFromWatchlist, Library::MarkNotInterested, Library::AddToWatchlist, Library::RemoveNotInterested ].each do |operation|
      assert_raises(Library::IdentityUnavailable) { operation.call(user_id: -1, library_film_id: @entry.id) }
      assert_raises(Library::FilmUnavailable) { operation.call(user_id: Identity::UserGuest.create!.id, library_film_id: @entry.id) }
      travel 25.hours do
        assert_raises(Library::IdentityUnavailable) { operation.call(user_id: @user.id, library_film_id: @entry.id) }
      end
    end
  end

  test "caller rollback and publication failure leave original entry and events intact" do
    [ Library::RecordWatched, Library::RemoveFromWatchlist ].each do |operation|
      assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
        Library::LibraryFilm.transaction(requires_new: true) do
          operation.call(user_id: @user.id, library_film_id: @entry.id)
          raise ActiveRecord::Rollback
        end
      end
      assert Library::LibraryFilm.find(@entry.id).can_watch?
    end
    failure = -> { raise ActiveRecord::StatementInvalid, "injected publication failure" }
    DomainEvents::DomainEvent.set_callback(:create, :before, failure)
    [ Library::RecordWatched, Library::RemoveFromWatchlist ].each do |operation|
      assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
        assert_raises(ActiveRecord::StatementInvalid) { operation.call(user_id: @user.id, library_film_id: @entry.id) }
      end
      assert Library::LibraryFilm.find(@entry.id).can_watch?
    end
  ensure
    DomainEvents::DomainEvent.skip_callback(:create, :before, failure, raise: false) if failure
  end

  test "dismissal detail operations roll back state and events on publication failure" do
    failure = -> { raise ActiveRecord::StatementInvalid, "injected publication failure" }
    DomainEvents::DomainEvent.set_callback(:create, :before, failure)
    assert_no_difference "DomainEvents::DomainEvent.count" do
      assert_raises(ActiveRecord::StatementInvalid) do
        Library::MarkNotInterested.call(user_id: @user.id, library_film_id: @entry.id)
      end
    end
    assert Library::LibraryFilm.find(@entry.id).can_watch?
    DomainEvents::DomainEvent.skip_callback(:create, :before, failure)
    Library::MarkNotInterested.call(user_id: @user.id, library_film_id: @entry.id)
    DomainEvents::DomainEvent.set_callback(:create, :before, failure)
    [ Library::AddToWatchlist, Library::RemoveNotInterested ].each do |operation|
      assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
        assert_raises(ActiveRecord::StatementInvalid) { operation.call(user_id: @user.id, library_film_id: @entry.id) }
      end
      assert Library::LibraryFilm.find(@entry.id).can_remove_from_not_interested?
    end
  ensure
    DomainEvents::DomainEvent.skip_callback(:create, :before, failure, raise: false) if failure
  end
end
