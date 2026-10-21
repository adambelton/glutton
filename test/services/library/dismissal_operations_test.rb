require "test_helper"

class Library::DismissalOperationsTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @user = UserGuest.create!
    @film = Film.create!(title: "Dismissal operations film")
  end

  def dismiss(user_id: @user.id, film_id: @film.id)
    Library::MarkNotInterested.call(user_id:, film_id:)
  end

  def remove(user_id: @user.id, film_id: @film.id)
    Library::RemoveNotInterested.call(user_id:, film_id:)
  end

  test "dismissal and removal return the entry and reject repeated actions" do
    assert_raises(Library::NotMarkedNotInterested) { remove }
    entry = dismiss
    assert entry.persisted?
    assert_equal @user.id, entry.user_id
    assert_equal @film.id, entry.film_id
    assert entry.can_add_to_watchlist?
    assert_raises(Library::DismissalUnavailable) { dismiss }
    assert_equal entry.updated_at, entry.reload.updated_at
    removed = remove
    assert removed.destroyed?
    assert_equal entry.id, removed.id
    assert_not LibraryFilm.exists?(entry.id)
    assert_raises(Library::NotMarkedNotInterested) { remove }
    assert dismiss.persisted?
  end

  test "watched entries reject both actions and retain relationship identity" do
    watched = Library::RecordWatched.call(user_id: @user.id, film_id: @film.id)
    assert_raises(Library::DismissalUnavailable) { dismiss }
    assert_raises(Library::NotMarkedNotInterested) { remove }
    row = LibraryFilm.find(watched.id)
    assert_equal watched.created_at, row.created_at
    assert_equal @user.id, row.user_id
    assert_equal @film.id, row.film_id
    assert_not row.can_watch?
    assert_raises(Library::AlreadyWatched) do
      Library::RecordWatched.call(user_id: @user.id, film_id: @film.id)
    end
  end

  test "dismissing a watchlist film transitions the same entry and permits dismissal removal" do
    original = LibraryFilmToWatch.create!(user: @user, film: @film)
    assert_raises(Library::NotMarkedNotInterested) { remove }
    travel 1.hour do
      assert_no_difference "LibraryFilm.count" do
        result = dismiss
        assert_equal original.id, result.id
        assert_equal original.created_at, result.created_at
        assert_equal @user.id, result.user_id
        assert_equal @film.id, result.film_id
        assert result.persisted?
        assert result.can_add_to_watchlist?
      end
      assert_raises(Library::DismissalUnavailable) { dismiss }
      assert_equal original.id, remove.id
      assert_not LibraryFilm.exists?(original.id)
    end
  end

  test "dismissal transition rolls back on caller rollback and destination save failure" do
    original = LibraryFilmToWatch.create!(user: @user, film: @film)
    LibraryFilm.transaction(requires_new: true) do
      dismiss
      raise ActiveRecord::Rollback
    end
    assert LibraryFilm.find(original.id).can_mark_not_interested?

    callback = -> { raise ActiveRecord::StatementInvalid, "injected dismissal transition failure" }
    LibraryFilmNotInterested.set_callback(:update, :after, callback)
    assert_raises(ActiveRecord::StatementInvalid) { dismiss }
    restored = LibraryFilm.find(original.id)
    assert restored.can_mark_not_interested?
    assert_equal original.created_at, restored.created_at
    LibraryFilmNotInterested.skip_callback(:update, :after, callback)
    assert_equal original.id, dismiss.id
    assert_raises(Library::DismissalUnavailable) { dismiss }
  ensure
    LibraryFilmNotInterested.skip_callback(:update, :after, callback, raise: false) if callback
  end

  test "registered users retain access and operations isolate owners" do
    entry = dismiss
    registered = UserRegistered.create!(email_address: "dismissal@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    assert_raises(Library::NotMarkedNotInterested) { remove(user_id: registered.id) }
    travel UserGuest::EXPIRY_DURATION * 2 do
      assert dismiss(user_id: registered.id).persisted?
      assert remove(user_id: registered.id).destroyed?
    end
    assert LibraryFilm.exists?(entry.id)
  end

  test "fresh identity and film lookups reject missing inactive and stale collaborators" do
    entry = dismiss
    missing = UserGuest.create!
    missing.destroy!
    @user.update_columns(type: "UserDeleted")
    [ nil, missing.id, @user.id ].each do |user_id|
      assert_raises(Library::IdentityUnavailable) { dismiss(user_id:) }
      assert_raises(Library::IdentityUnavailable) { remove(user_id:) }
    end
    active = UserGuest.create!
    removed_film = Film.create!(title: "Removed film")
    removed_film.destroy!
    [ nil, removed_film.id ].each do |film_id|
      assert_raises(Library::FilmUnavailable) { dismiss(user_id: active.id, film_id:) }
      assert_raises(Library::FilmUnavailable) { remove(user_id: active.id, film_id:) }
    end
    assert LibraryFilm.exists?(entry.id)
    assert_equal 1, LibraryFilm.count
  end

  test "guest deadline rejects both actions without deleting activity" do
    travel_to @user.created_at + UserGuest::EXPIRY_DURATION - 1.second
    assert dismiss.persisted?
    assert remove.destroyed?
    entry = dismiss
    travel 1.second
    assert_raises(Library::IdentityUnavailable) { dismiss }
    assert_raises(Library::IdentityUnavailable) { remove }
    assert LibraryFilm.exists?(entry.id)
  end

  test "caller rollback reverses dismissal and removal and allows retry" do
    LibraryFilm.transaction(requires_new: true) do
      dismiss
      raise ActiveRecord::Rollback
    end
    assert_not LibraryFilm.exists?(user: @user, film: @film)
    entry = dismiss
    LibraryFilm.transaction(requires_new: true) do
      remove
      raise ActiveRecord::Rollback
    end
    assert LibraryFilm.exists?(entry.id)
    assert remove.destroyed?
  end

  test "persistence failures propagate and restore state before explicit retry" do
    [ :create, :destroy ].each do |action|
      callback = -> { raise ActiveRecord::StatementInvalid, "injected dismissal failure" }
      LibraryFilmNotInterested.set_callback(action, :after, callback)
      begin
        if action == :create
          assert_raises(ActiveRecord::StatementInvalid) { dismiss }
          assert_not LibraryFilm.exists?(user: @user, film: @film)
        else
          assert_raises(ActiveRecord::StatementInvalid) { remove }
          assert LibraryFilm.exists?(user: @user, film: @film)
        end
      ensure
        LibraryFilmNotInterested.skip_callback(action, :after, callback)
      end
      action == :create ? assert(dismiss.persisted?) : assert(remove.destroyed?)
    end
  end

  test "claim retains dismissal identity and cleanup removes expired entries only" do
    original = dismiss
    pending = Identity::PrepareRegistration.call(email_address: "dismissal-claim@example.test", guest_user_id: @user.id,
      password: "a long password phrase", password_confirmation: "a long password phrase")
    token = Identity::RegistrationConfirmation.token_for(pending_registration_id: pending.id)
    session = Identity::CompleteRegistration.call(token:)
    assert_equal @user.id, session.user_id
    assert_equal original.created_at, LibraryFilm.find(original.id).created_at
    expired = UserGuest.create!
    dismiss(user_id: expired.id)
    travel UserGuest::EXPIRY_DURATION do
      assert_raises(Library::IdentityUnavailable) { remove(user_id: expired.id) }
      assert_equal 1, Identity::CleanupExpiredAccounts.call[:guests_deleted]
      assert_not LibraryFilm.exists?(user_id: expired.id)
      assert Film.exists?(@film.id)
      assert_equal original.id, remove.id
    end
  end
end
