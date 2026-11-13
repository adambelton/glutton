require "test_helper"

class Library::EntryOperationsTest < ActiveSupport::TestCase
  OPERATIONS = [
    [ Library::CollectionManagement::MoveWatchlistToWatched, Library::LibraryFilm, :can_move_to_watched?, Library::Errors::AlreadyWatched ],
    [ Library::CollectionManagement::RemoveFromWatchlist, Library::LibraryFilm, :can_remove_from_watchlist?, Library::Errors::NotOnWatchlist ]
  ].freeze

  DESTINATION_PERMISSIONS = {
    Library::CollectionManagement::MoveWatchlistToWatched => :can_rate?
  }.freeze

  setup do
    freeze_time
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "Existing Library film")
  end

  OPERATIONS.each do |operation, source, permission, rejection|
    test "#{operation} requires the exact owned existing entry and never creates" do
      foreign = source.create!(user: Identity::UserGuest.create!, film: @film)
      assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
        [ nil, -1, foreign.id ].each do |id|
          assert_raises(Library::Errors::FilmUnavailable) { operation.call(user_id: @user.id, library_film_id: id) }
        end
      end
      removed = source.create!(user: @user, film: @film)
      removed.destroy!
      replacement = source.create!(user: @user, film: @film)
      assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
        assert_raises(Library::Errors::FilmUnavailable) { operation.call(user_id: @user.id, library_film_id: removed.id) }
      end
      assert replacement.reload.public_send(permission)
    end

    test "#{operation} returns its outcome and rejects repeated or unsupported actions" do
      entry = source.create!(user: @user, film: @film)
      result = operation.call(user_id: @user.id, library_film_id: entry.id)
      assert_equal entry.id, result.id
      assert_equal entry.created_at, result.created_at
      assert_equal entry.user_id, result.user_id
      destination_permission = DESTINATION_PERMISSIONS[operation]
      if destination_permission.present?
        assert Library::LibraryFilm.find(entry.id).public_send(destination_permission)
        error = rejection
      else
        assert_not Library::LibraryFilm.exists?(entry.id)
        error = Library::Errors::FilmUnavailable
      end
      assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
        assert_raises(error) { operation.call(user_id: @user.id, library_film_id: entry.id) }
        watched = Library::LibraryFilm.create!(watched: true, user: @user, film: Registry::Film.create!(title: "Watched"))
        assert_raises(rejection) { operation.call(user_id: @user.id, library_film_id: watched.id) }
        watched.destroy!
      end
    end

    test "#{operation} validates fresh identity and permits registered users beyond guest expiry" do
      entry = source.create!(user: @user, film: @film)
      [ nil, -1, Identity::UserDeleted.create!.id ].each do |id|
        assert_raises(Identity::Errors::Unavailable) { operation.call(user_id: id, library_film_id: entry.id) }
      end
      travel_to @user.created_at + Identity::UserGuest::EXPIRY_DURATION do
        assert_raises(Identity::Errors::Unavailable) { operation.call(user_id: @user.id, library_film_id: entry.id) }
      end
      registered = Identity::UserRegistered.create!(email_address: "entry@example.test", password: "long test password", password_confirmation: "long test password", email_confirmed_at: Time.current)
      owned = source.create!(user: registered, film: @film)
      travel 2.days do
        assert_equal owned.id, operation.call(user_id: registered.id, library_film_id: owned.id).id
      end
    end

    test "#{operation} rolls back with caller and publication failure and permits explicit retry" do
      entry = source.create!(user: @user, film: @film)
      assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count", "DomainEvents::DomainEventStream.count" ] do
        Library::LibraryFilm.transaction(requires_new: true) do
          operation.call(user_id: @user.id, library_film_id: entry.id)
          raise ActiveRecord::Rollback
        end
      end
      assert Library::LibraryFilm.find(entry.id).public_send(permission)
      callback = -> { raise ActiveRecord::StatementInvalid, "injected publication failure" }
      DomainEvents::DomainEvent.set_callback(:create, :before, callback)
      assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count", "DomainEvents::DomainEventStream.count" ] do
        assert_raises(ActiveRecord::StatementInvalid) { operation.call(user_id: @user.id, library_film_id: entry.id) }
      end
      assert Library::LibraryFilm.find(entry.id).public_send(permission)
      DomainEvents::DomainEvent.skip_callback(:create, :before, callback)
      assert_equal entry.id, operation.call(user_id: @user.id, library_film_id: entry.id).id
    ensure
      DomainEvents::DomainEvent.skip_callback(:create, :before, callback, raise: false) if callback
    end
  end

  [ [ Library::CollectionManagement::MoveWatchlistToWatched, :update, :can_move_to_watched? ],
    [ Library::CollectionManagement::RemoveFromWatchlist, :destroy, :can_remove_from_watchlist? ] ].each do |operation, action, permission|
    test "#{operation} restores its source on persistence failure" do
      entry = Library::LibraryFilm.create!(user: @user, film: @film)
      callback = -> { raise ActiveRecord::StatementInvalid, "injected persistence failure" }
      Library::LibraryFilm.set_callback(action, :after, callback)
      assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
        assert_raises(ActiveRecord::StatementInvalid) { operation.call(user_id: @user.id, library_film_id: entry.id) }
      end
      assert Library::LibraryFilm.find(entry.id).public_send(permission)
      Library::LibraryFilm.skip_callback(action, :after, callback)
      assert_equal entry.id, operation.call(user_id: @user.id, library_film_id: entry.id).id
    ensure
      Library::LibraryFilm.skip_callback(action, :after, callback, raise: false) if callback
    end
  end
end
