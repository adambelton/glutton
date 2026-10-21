require "test_helper"

class Library::WatchlistOperationsTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @user = UserGuest.create!
    @film = Film.create!(title: "Watchlist operations film")
  end

  def add(user_id: @user.id, film_id: @film.id)
    Library::AddToWatchlist.call(user_id:, film_id:)
  end

  def remove(user_id: @user.id, film_id: @film.id)
    Library::RemoveFromWatchlist.call(user_id:, film_id:)
  end

  test "addition and removal return the entry and reject repeated actions" do
    assert_raises(Library::NotOnWatchlist) { remove }
    entry = add
    assert entry.persisted?
    assert_equal @user.id, entry.user_id
    assert_equal @film.id, entry.film_id
    assert entry.can_watch?
    assert_raises(Library::WatchlistUnavailable) { add }
    assert_equal entry.updated_at, entry.reload.updated_at
    removed = remove
    assert removed.destroyed?
    assert_equal entry.id, removed.id
    assert_not LibraryFilm.exists?(entry.id)
    assert_raises(Library::NotOnWatchlist) { remove }
    assert add.persisted?
  end

  test "watched entries reject both actions and retain relationship identity" do
    original = add
    watched = Library::RecordWatched.call(user_id: @user.id, film_id: @film.id)
    assert_equal original.id, watched.id
    assert_equal original.created_at, watched.created_at
    assert_raises(Library::WatchlistUnavailable) { add }
    assert_raises(Library::NotOnWatchlist) { remove }
    row = LibraryFilm.find(original.id)
    assert_equal @user.id, row.user_id
    assert_equal @film.id, row.film_id
    assert_not row.can_watch?
    assert_raises(Library::AlreadyWatched) do
      Library::RecordWatched.call(user_id: @user.id, film_id: @film.id)
    end
  end

  test "reconsidering a film transitions the same entry and permits watchlist removal" do
    original = LibraryFilmNotInterested.create!(user: @user, film: @film)
    assert_raises(Library::NotOnWatchlist) { remove }
    travel 1.hour do
      assert_no_difference "LibraryFilm.count" do
        result = add
        assert_equal original.id, result.id
        assert_equal original.created_at, result.created_at
        assert_equal @user.id, result.user_id
        assert_equal @film.id, result.film_id
        assert result.persisted?
        assert result.can_watch?
      end
      assert_raises(Library::WatchlistUnavailable) { add }
      assert_equal original.id, remove.id
      assert_not LibraryFilm.exists?(original.id)
    end
  end

  test "reconsideration rolls back on caller rollback and destination save failure" do
    original = LibraryFilmNotInterested.create!(user: @user, film: @film)
    LibraryFilm.transaction(requires_new: true) do
      add
      raise ActiveRecord::Rollback
    end
    assert LibraryFilm.find(original.id).can_add_to_watchlist?

    callback = -> { raise ActiveRecord::StatementInvalid, "injected reconsideration failure" }
    LibraryFilmToWatch.set_callback(:update, :after, callback)
    assert_raises(ActiveRecord::StatementInvalid) { add }
    restored = LibraryFilm.find(original.id)
    assert restored.can_add_to_watchlist?
    assert_equal original.created_at, restored.created_at
    LibraryFilmToWatch.skip_callback(:update, :after, callback)
    assert_equal original.id, add.id
    assert_raises(Library::WatchlistUnavailable) { add }
  ensure
    LibraryFilmToWatch.skip_callback(:update, :after, callback, raise: false) if callback
  end

  test "registered users retain access and operations isolate owners" do
    entry = add
    registered = UserRegistered.create!(email_address: "watchlist@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    assert_raises(Library::NotOnWatchlist) { remove(user_id: registered.id) }
    travel UserGuest::EXPIRY_DURATION * 2 do
      assert add(user_id: registered.id).persisted?
      assert remove(user_id: registered.id).destroyed?
    end
    assert LibraryFilm.exists?(entry.id)
  end

  test "fresh identity and film lookups reject missing inactive and stale collaborators" do
    entry = add
    missing = UserGuest.create!
    missing.destroy!
    @user.update_columns(type: "UserDeleted")
    [ nil, missing.id, @user.id ].each do |user_id|
      assert_raises(Library::IdentityUnavailable) { add(user_id:) }
      assert_raises(Library::IdentityUnavailable) { remove(user_id:) }
    end
    active = UserGuest.create!
    removed_film = Film.create!(title: "Removed film")
    removed_film.destroy!
    [ nil, removed_film.id ].each do |film_id|
      assert_raises(Library::FilmUnavailable) { add(user_id: active.id, film_id:) }
      assert_raises(Library::FilmUnavailable) { remove(user_id: active.id, film_id:) }
    end
    assert LibraryFilm.exists?(entry.id)
    assert_equal 1, LibraryFilm.count
  end

  test "guest deadline rejects both actions without deleting activity" do
    travel_to @user.created_at + UserGuest::EXPIRY_DURATION - 1.second
    assert add.persisted?
    assert remove.destroyed?
    entry = add
    travel 1.second
    assert_raises(Library::IdentityUnavailable) { add }
    assert_raises(Library::IdentityUnavailable) { remove }
    assert LibraryFilm.exists?(entry.id)
  end

  test "caller rollback reverses addition and removal and allows retry" do
    LibraryFilm.transaction(requires_new: true) do
      add
      raise ActiveRecord::Rollback
    end
    assert_not LibraryFilm.exists?(user: @user, film: @film)
    entry = add
    LibraryFilm.transaction(requires_new: true) do
      remove
      raise ActiveRecord::Rollback
    end
    assert LibraryFilm.exists?(entry.id)
    assert remove.destroyed?
  end

  test "persistence failures propagate and restore state before explicit retry" do
    [ :create, :destroy ].each do |action|
      callback = -> { raise ActiveRecord::StatementInvalid, "injected watchlist failure" }
      LibraryFilmToWatch.set_callback(action, :after, callback)
      begin
        if action == :create
          assert_raises(ActiveRecord::StatementInvalid) { add }
          assert_not LibraryFilm.exists?(user: @user, film: @film)
        else
          assert_raises(ActiveRecord::StatementInvalid) { remove }
          assert LibraryFilm.exists?(user: @user, film: @film)
        end
      ensure
        LibraryFilmToWatch.skip_callback(action, :after, callback)
      end
      action == :create ? assert(add.persisted?) : assert(remove.destroyed?)
    end
  end

  test "claim retains watchlist identity and cleanup removes expired entries only" do
    original = add
    pending = Identity::PrepareRegistration.call(email_address: "watchlist-claim@example.test", guest_user_id: @user.id,
      password: "a long password phrase", password_confirmation: "a long password phrase")
    token = Identity::RegistrationConfirmation.token_for(pending_registration_id: pending.id)
    session = Identity::CompleteRegistration.call(token:)
    assert_equal @user.id, session.user_id
    assert_equal original.created_at, LibraryFilm.find(original.id).created_at
    expired = UserGuest.create!
    add(user_id: expired.id)
    travel UserGuest::EXPIRY_DURATION do
      assert_raises(Library::IdentityUnavailable) { remove(user_id: expired.id) }
      assert_equal 1, Identity::CleanupExpiredAccounts.call[:guests_deleted]
      assert_not LibraryFilm.exists?(user_id: expired.id)
      assert Film.exists?(@film.id)
      assert_equal original.id, remove.id
    end
  end
end
