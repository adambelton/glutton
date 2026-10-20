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

  def state(user: @user, film: @film)
    Library::FilmState.call(user:, film:)
  end

  test "unclassified reads write nothing and recording watched is stable on repeats" do
    assert_no_difference "LibraryFilm.count" do
      assert_equal({ film_id: @film.id, classification: :unclassified, watched_at: nil }, state)
    end
    result = freeze_time { record }
    row = LibraryFilm.find_by!(user: @user, film: @film)
    attributes = row.attributes
    assert_equal({ film_id: @film.id, classification: :watched, watched_at: row.watched_at }, result)
    travel 1.hour do
      assert_no_difference "LibraryFilm.count" do
        assert_equal result, record
        assert_equal result, state
      end
      assert_equal attributes, row.reload.attributes
    end
  end

  test "users and guests see and change only their own film relationship" do
    record
    other = UserGuest.create!
    assert_equal :unclassified, state(user: other)[:classification]
    assert_difference("LibraryFilm.count", 1) { record(user: other) }
    assert_equal 1, LibraryFilm.where(user: @user).count
    assert_equal 1, LibraryFilm.where(user: other).count
  end

  test "guest access ends at the exact fixed deadline for reads and writes" do
    [ -1.second, 0.seconds, 1.second ].each do |offset|
      travel_to @user.created_at + 24.hours + offset do
        if offset.negative?
          assert_equal :watched, record[:classification]
          assert_equal :watched, state[:classification]
        else
          assert_no_difference "LibraryFilm.count" do
            assert_raises(Library::IdentityUnavailable) { record }
            assert_raises(Library::IdentityUnavailable) { state }
          end
        end
      end
    end
  end

  test "registered users have no guest deadline and stale actors are re-read" do
    registered = UserRegistered.create!(email_address: "library@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    travel 48.hours do
      assert_equal :watched, record(user: registered)[:classification]
      assert_equal :watched, state(user: registered)[:classification]
    end
    @user.update_columns(type: "UserDeleted")
    assert_instance_of UserGuest, @user
    assert_raises(Library::IdentityUnavailable) { record }
    assert_raises(Library::IdentityUnavailable) { state }
  end

  test "invalid identities and absent films fail without saving activity" do
    missing = UserGuest.create!
    User.where(id: missing.id).delete_all
    [ nil, UserGuest.new, UserDeleted.create!, missing ].each do |actor|
      assert_no_difference "LibraryFilm.count" do
        assert_raises(Library::IdentityUnavailable) { record(user: actor, film: nil) }
        assert_raises(Library::IdentityUnavailable) { state(user: actor, film: nil) }
      end
    end
    stale_film = Film.create!(title: "Removed film")
    Film.where(id: stale_film.id).delete_all
    [ nil, Film.new, Film.new(id: @film.id), stale_film ].each do |film|
      assert_raises(Library::FilmUnavailable) { record(film:) }
      assert_raises(Library::FilmUnavailable) { state(film:) }
    end
    assert_equal 0, LibraryFilm.count
  end

  test "internal model collaborators are accepted through behaviour rather than concrete class" do
    actor = SimpleDelegator.new(@user)
    movie = SimpleDelegator.new(@film)
    assert_not actor.is_a?(User)
    assert_not movie.is_a?(Film)
    result = record(user: actor, film: movie)
    assert_equal result, state(user: actor, film: movie)
    assert_equal @film.id, result[:film_id]
    assert_equal :watched, result[:classification]
  end

  test "outer rollback and persistence failure leave no partial watched record" do
    LibraryFilm.transaction(requires_new: true) do
      record
      assert_equal :watched, state[:classification]
      raise ActiveRecord::Rollback
    end
    assert_equal :unclassified, state[:classification]
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
