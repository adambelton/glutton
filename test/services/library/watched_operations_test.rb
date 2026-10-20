require "test_helper"

class Library::WatchedOperationsTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @user = UserGuest.create!
    @film = Film.create!(title: "Watched operations film")
  end

  def record(user_id: @user.id, film_id: @film.id)
    Library::RecordWatched.call(user_id:, film_id:)
  end

  test "recording watched returns the relationship and is stable on repeats" do
    result = record
    assert result.persisted?
    assert_equal @user.id, result.user_id
    assert_equal @film.id, result.film_id
    travel 1.hour do
      assert_no_difference "LibraryFilm.count" do
        repeated = record
        assert_equal result.id, repeated.id
        assert_equal result.created_at, repeated.created_at
        assert_equal result.updated_at, repeated.updated_at
      end
    end
  end

  test "recording a to-watch film transitions the same relationship and returns watched behaviour" do
    original = LibraryFilmToWatch.create!(user: @user, film: @film)
    travel 1.hour do
      assert_no_difference "LibraryFilm.count" do
        watched = record
        assert_equal original.id, watched.id
        assert_equal @user.id, watched.user_id
        assert_equal @film.id, watched.film_id
        assert_equal original.created_at, watched.created_at
        assert_not watched.can_watch?
        assert_equal watched, watched.record_watched
        assert_equal watched, LibraryFilm.find(original.id).record_watched
        assert_equal watched.updated_at, record.updated_at
      end
    end
  end

  test "watched transition rolls back with caller transaction and destination save failure" do
    original = LibraryFilmToWatch.create!(user: @user, film: @film)
    LibraryFilm.transaction(requires_new: true) do
      record
      raise ActiveRecord::Rollback
    end
    assert LibraryFilm.find(original.id).can_watch?

    callback = -> { raise ActiveRecord::StatementInvalid, "injected transition failure" }
    LibraryFilmWatched.set_callback(:update, :after, callback)
    assert_raises(ActiveRecord::StatementInvalid) { record }
    assert LibraryFilm.find(original.id).can_watch?
    LibraryFilmWatched.skip_callback(:update, :after, callback)
    assert_equal original.id, record.id
    assert_not LibraryFilm.find(original.id).can_watch?
  ensure
    LibraryFilmWatched.skip_callback(:update, :after, callback, raise: false) if callback
  end

  test "users and guests see and change only their own film relationship" do
    record
    other = UserGuest.create!
    assert_difference("LibraryFilm.count", 1) { record(user_id: other.id) }
    assert_equal 1, LibraryFilm.where(user: @user).count
    assert_equal 1, LibraryFilm.where(user: other).count
  end

  test "guest access ends at the exact fixed deadline for writes" do
    [ -1.second, 0.seconds, 1.second ].each do |offset|
      travel_to @user.created_at + 24.hours + offset do
        if offset.negative?
          assert record.persisted?
        else
          assert_no_difference "LibraryFilm.count" do
            assert_raises(Library::IdentityUnavailable) { record }
          end
        end
      end
    end
  end

  test "registered users have no guest deadline and stale actors are re-read" do
    registered = UserRegistered.create!(email_address: "library@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    travel 48.hours do
      assert record(user_id: registered.id).persisted?
    end
    @user.update_columns(type: "UserDeleted")
    assert_raises(Library::IdentityUnavailable) { record }
  end

  test "invalid identities and absent films fail without saving activity" do
    missing = UserGuest.create!
    User.where(id: missing.id).delete_all
    [ nil, UserDeleted.create!.id, missing.id ].each do |user_id|
      assert_no_difference "LibraryFilm.count" do
        assert_raises(Library::IdentityUnavailable) { record(user_id:, film_id: nil) }
      end
    end
    removed_film = Film.create!(title: "Removed film")
    Film.where(id: removed_film.id).delete_all
    [ nil, removed_film.id ].each do |film_id|
      assert_raises(Library::FilmUnavailable) { record(film_id:) }
    end
    assert_equal 0, LibraryFilm.count
  end

  test "outer rollback and persistence failure leave no partial watched record" do
    LibraryFilm.transaction(requires_new: true) do
      record
      raise ActiveRecord::Rollback
    end
    assert_not LibraryFilm.exists?(user: @user, film: @film)
    callback = -> { raise ActiveRecord::StatementInvalid, "injected Library failure" }
    LibraryFilmWatched.set_callback(:create, :after, callback)
    assert_no_difference "LibraryFilm.count" do
      assert_raises(ActiveRecord::StatementInvalid) { record }
    end
    LibraryFilmWatched.skip_callback(:create, :after, callback)
    assert_difference("LibraryFilm.count", 1) { record }
  ensure
    LibraryFilmWatched.skip_callback(:create, :after, callback, raise: false) if callback
  end
end
