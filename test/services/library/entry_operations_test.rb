require "test_helper"

class Library::EntryOperationsTest < ActiveSupport::TestCase
  OPERATIONS = [
    [ Library::RecordWatched, LibraryFilmToWatch, :can_watch?, Library::AlreadyWatched ],
    [ Library::AddToWatchlist, LibraryFilmNotInterested, :can_add_to_watchlist?, Library::WatchlistUnavailable ],
    [ Library::MarkNotInterested, LibraryFilmToWatch, :can_mark_not_interested?, Library::DismissalUnavailable ],
    [ Library::RemoveFromWatchlist, LibraryFilmToWatch, :can_remove_from_watchlist?, Library::NotOnWatchlist ],
    [ Library::RemoveNotInterested, LibraryFilmNotInterested, :can_remove_from_not_interested?, Library::NotMarkedNotInterested ]
  ].freeze

  setup do
    freeze_time
    @user = UserGuest.create!
    @film = Film.create!(title: "Existing Library film")
  end

  OPERATIONS.each do |operation, source, permission, rejection|
    test "#{operation} requires the exact owned existing entry and never creates" do
      foreign = source.create!(user: UserGuest.create!, film: @film)
      assert_no_difference [ "LibraryFilm.count", "DomainEvent.count" ] do
        [ nil, -1, foreign.id ].each do |id|
          assert_raises(Library::FilmUnavailable) { operation.call(user_id: @user.id, library_film_id: id) }
        end
      end
      removed = source.create!(user: @user, film: @film)
      removed.destroy!
      replacement = source.create!(user: @user, film: @film)
      assert_no_difference [ "LibraryFilm.count", "DomainEvent.count" ] do
        assert_raises(Library::FilmUnavailable) { operation.call(user_id: @user.id, library_film_id: removed.id) }
      end
      assert replacement.reload.public_send(permission)
    end

    test "#{operation} returns its outcome and rejects repeated or unsupported actions" do
      entry = source.create!(user: @user, film: @film)
      result = operation.call(user_id: @user.id, library_film_id: entry.id)
      assert_equal entry.id, result.id
      assert_equal entry.created_at, result.created_at
      assert_equal entry.user_id, result.user_id
      if result.destroyed?
        assert_not LibraryFilm.exists?(entry.id)
        error = Library::FilmUnavailable
      else
        assert_not result.public_send(permission)
        error = rejection
      end
      assert_no_difference [ "LibraryFilm.count", "DomainEvent.count" ] do
        assert_raises(error) { operation.call(user_id: @user.id, library_film_id: entry.id) }
        watched = LibraryFilmWatched.create!(user: @user, film: Film.create!(title: "Watched"))
        assert_raises(rejection) { operation.call(user_id: @user.id, library_film_id: watched.id) }
        watched.destroy!
      end
    end

    test "#{operation} validates fresh identity and permits registered users beyond guest expiry" do
      entry = source.create!(user: @user, film: @film)
      [ nil, -1, UserDeleted.create!.id ].each do |id|
        assert_raises(Library::IdentityUnavailable) { operation.call(user_id: id, library_film_id: entry.id) }
      end
      travel_to @user.created_at + UserGuest::EXPIRY_DURATION do
        assert_raises(Library::IdentityUnavailable) { operation.call(user_id: @user.id, library_film_id: entry.id) }
      end
      registered = UserRegistered.create!(email_address: "entry@example.test", password: "long test password", password_confirmation: "long test password", email_confirmed_at: Time.current)
      owned = source.create!(user: registered, film: @film)
      travel 2.days do
        assert_equal owned.id, operation.call(user_id: registered.id, library_film_id: owned.id).id
      end
      @user.becomes!(UserDeleted).save!
      assert_raises(Library::IdentityUnavailable) { operation.call(user_id: @user.id, library_film_id: entry.id) }
    end

    test "#{operation} rolls back with caller and publication failure and permits explicit retry" do
      entry = source.create!(user: @user, film: @film)
      assert_no_difference [ "LibraryFilm.count", "DomainEvent.count", "DomainEventStream.count" ] do
        LibraryFilm.transaction(requires_new: true) do
          operation.call(user_id: @user.id, library_film_id: entry.id)
          raise ActiveRecord::Rollback
        end
      end
      assert LibraryFilm.find(entry.id).public_send(permission)
      callback = -> { raise ActiveRecord::StatementInvalid, "injected publication failure" }
      DomainEvent.set_callback(:create, :before, callback)
      assert_no_difference [ "LibraryFilm.count", "DomainEvent.count", "DomainEventStream.count" ] do
        assert_raises(ActiveRecord::StatementInvalid) { operation.call(user_id: @user.id, library_film_id: entry.id) }
      end
      assert LibraryFilm.find(entry.id).public_send(permission)
      DomainEvent.skip_callback(:create, :before, callback)
      assert_equal entry.id, operation.call(user_id: @user.id, library_film_id: entry.id).id
    ensure
      DomainEvent.skip_callback(:create, :before, callback, raise: false) if callback
    end
  end

  test "guest can act just before expiry and NotInterested cannot be marked watched by a user" do
    entry = LibraryFilmToWatch.create!(user: @user, film: @film)
    travel_to @user.created_at + UserGuest::EXPIRY_DURATION - 1.second do
      assert_equal entry.id, Library::MarkNotInterested.call(user_id: @user.id, library_film_id: entry.id).id
      assert_raises(Library::AlreadyWatched) { Library::RecordWatched.call(user_id: @user.id, library_film_id: entry.id) }
    end
  end

  [ [ Library::RecordWatched, LibraryFilmToWatch, LibraryFilmWatched, :update, :can_watch? ],
    [ Library::AddToWatchlist, LibraryFilmNotInterested, LibraryFilmToWatch, :update, :can_add_to_watchlist? ],
    [ Library::MarkNotInterested, LibraryFilmToWatch, LibraryFilmNotInterested, :update, :can_mark_not_interested? ],
    [ Library::RemoveFromWatchlist, LibraryFilmToWatch, LibraryFilmToWatch, :destroy, :can_remove_from_watchlist? ],
    [ Library::RemoveNotInterested, LibraryFilmNotInterested, LibraryFilmNotInterested, :destroy, :can_remove_from_not_interested? ] ].each do |operation, source, destination, action, permission|
    test "#{operation} restores its source on persistence failure" do
      entry = source.create!(user: @user, film: @film)
      callback = -> { raise ActiveRecord::StatementInvalid, "injected persistence failure" }
      destination.set_callback(action, :after, callback)
      assert_no_difference [ "LibraryFilm.count", "DomainEvent.count" ] do
        assert_raises(ActiveRecord::StatementInvalid) { operation.call(user_id: @user.id, library_film_id: entry.id) }
      end
      assert LibraryFilm.find(entry.id).public_send(permission)
      destination.skip_callback(action, :after, callback)
      assert_equal entry.id, operation.call(user_id: @user.id, library_film_id: entry.id).id
    ensure
      destination.skip_callback(action, :after, callback, raise: false) if callback
    end
  end
end
