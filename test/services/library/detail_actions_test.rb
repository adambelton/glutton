require "test_helper"

class Library::DetailActionsTest < ActiveSupport::TestCase
  setup do
    @user = UserGuest.create!
    @film = Film.create!(title: "Detail film")
    @entry = LibraryFilmToWatch.create!(user: @user, film: @film)
  end

  test "missing and inactive owners and foreign entries cannot be used" do
    [ Library::FindFilm, Library::WatchFilm, Library::RemoveWatchlistFilm ].each do |operation|
      assert_raises(Library::IdentityUnavailable) { operation.call(user_id: -1, library_film_id: @entry.id) }
      assert_raises(Library::FilmUnavailable) { operation.call(user_id: UserGuest.create!.id, library_film_id: @entry.id) }
      travel 25.hours do
        assert_raises(Library::IdentityUnavailable) { operation.call(user_id: @user.id, library_film_id: @entry.id) }
      end
    end
  end

  test "caller rollback and publication failure leave original entry and events intact" do
    [ Library::WatchFilm, Library::RemoveWatchlistFilm ].each do |operation|
      assert_no_difference [ "LibraryFilm.count", "DomainEvent.count" ] do
        LibraryFilm.transaction(requires_new: true) do
          operation.call(user_id: @user.id, library_film_id: @entry.id)
          raise ActiveRecord::Rollback
        end
      end
      assert LibraryFilm.find(@entry.id).can_watch?
    end
    failure = -> { raise ActiveRecord::StatementInvalid, "injected publication failure" }
    DomainEvent.set_callback(:create, :before, failure)
    [ Library::WatchFilm, Library::RemoveWatchlistFilm ].each do |operation|
      assert_no_difference [ "LibraryFilm.count", "DomainEvent.count" ] do
        assert_raises(ActiveRecord::StatementInvalid) { operation.call(user_id: @user.id, library_film_id: @entry.id) }
      end
      assert LibraryFilm.find(@entry.id).can_watch?
    end
  ensure
    DomainEvent.skip_callback(:create, :before, failure, raise: false) if failure
  end
end
