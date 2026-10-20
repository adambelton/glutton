require "test_helper"
require "delegate"

class Library::WatchedOperationsTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @user = UserGuest.create!
    @film = Film.create!(title: "Watched operations film")
  end

  def record(user: @user, film: @film)
    Library::RecordWatched.call(user:, film:)
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

  test "users and guests see and change only their own film relationship" do
    record
    other = UserGuest.create!
    assert_difference("LibraryFilm.count", 1) { record(user: other) }
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
      assert record(user: registered).persisted?
    end
    @user.update_columns(type: "UserDeleted")
    assert_raises(Library::IdentityUnavailable) { record }
  end

  test "invalid identities and absent films fail without saving activity" do
    missing = UserGuest.create!
    User.where(id: missing.id).delete_all
    [ nil, UserGuest.new, UserDeleted.create!, missing ].each do |actor|
      assert_no_difference "LibraryFilm.count" do
        assert_raises(Library::IdentityUnavailable) { record(user: actor, film: nil) }
      end
    end
    stale_film = Film.create!(title: "Removed film")
    Film.where(id: stale_film.id).delete_all
    [ nil, Film.new, Film.new(id: @film.id), stale_film ].each do |film|
      assert_raises(Library::FilmUnavailable) { record(film:) }
    end
    assert_equal 0, LibraryFilm.count
  end

  test "internal model collaborators are accepted through behaviour rather than concrete class" do
    user = SimpleDelegator.new(@user)
    film = SimpleDelegator.new(@film)
    result = record(user:, film:)
    assert_equal @film.id, result.film_id
    assert result.persisted?
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
