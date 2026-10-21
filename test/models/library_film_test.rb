require "test_helper"

class LibraryFilmTest < ActiveSupport::TestCase
  setup do
    @user = UserGuest.create!
    @film = Film.create!(title: "Library model film")
  end

  def attributes
    { user_id: @user.id, film_id: @film.id }
  end

  test "watched subtype uses default STI mapping and shared relationship uniqueness" do
    row = LibraryFilmWatched.create!(attributes)
    loaded = LibraryFilm.find(row.id)
    assert_equal row, loaded
    duplicate = LibraryFilmWatched.new(attributes)
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:film_id, :taken)
    assert LibraryFilmWatched.create!(attributes.merge(user: UserGuest.create!)).persisted?
    assert_raises(ActiveRecord::RecordNotUnique) { insert(attributes.merge(type: "LibraryFilmWatched")) }
  end

  test "watch permission defaults to denied and to-watch entries permit it" do
    assert_not LibraryFilmWatched.new.can_watch?
    assert LibraryFilmToWatch.new.can_watch?
  end

  test "watchlist addition error is present only when the action is denied" do
    assert_nil LibraryFilmNotInterested.new.watchlist_addition_error
    assert_equal Library::WatchlistUnavailable, LibraryFilmToWatch.new.watchlist_addition_error
    assert_equal Library::WatchlistUnavailable, LibraryFilmWatched.new.watchlist_addition_error
  end

  test "dismissal permission and error agree for supported entries" do
    assert LibraryFilmToWatch.new.can_mark_not_interested?
    assert_nil LibraryFilmToWatch.new.dismissal_error
    assert_not LibraryFilmWatched.new.can_mark_not_interested?
    assert_equal Library::DismissalUnavailable, LibraryFilmWatched.new.dismissal_error
    assert_not LibraryFilmNotInterested.new.can_mark_not_interested?
    assert_equal Library::DismissalUnavailable, LibraryFilmNotInterested.new.dismissal_error
  end

  test "subtypes share one user-film relationship" do
    LibraryFilmToWatch.create!(attributes)
    duplicate = LibraryFilmWatched.new(attributes)
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:film_id, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) { insert(attributes.merge(type: "LibraryFilmWatched")) }
  end

  test "root construction is prohibited while subtype construction and loading work" do
    assert_raises(NotImplementedError) { LibraryFilm.new(attributes) }
    assert_raises(NotImplementedError) { LibraryFilm.create!(attributes) }
    row = LibraryFilmWatched.create!(attributes)
    assert_equal row, LibraryFilm.find(row.id)
    assert_raises(ActiveRecord::NotNullViolation) { insert(attributes.merge(type: nil)) }
  end

  test "foreign keys require real owners and films and preserve referenced films" do
    assert_raises(ActiveRecord::InvalidForeignKey) { insert(attributes.merge(type: "LibraryFilmWatched", user_id: User.maximum(:id) + 1)) }
    assert_raises(ActiveRecord::InvalidForeignKey) { insert(attributes.merge(type: "LibraryFilmWatched", film_id: Film.maximum(:id) + 1)) }
    LibraryFilmWatched.create!(attributes)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Film.transaction(requires_new: true) { @film.destroy! }
    end
    assert Film.exists?(@film.id)
  end

  test "validation messages resolve through English locales with strict translation checks" do
    assert_equal :strict, Rails.application.config.i18n.raise_on_missing_translations
    I18n.with_locale(:en) do
      row = LibraryFilmWatched.new
      row.valid?
      assert_includes row.errors.full_messages, "User must exist"
      assert_includes row.errors.full_messages, "Film must exist"
    end
  end

  private

  def insert(values)
    LibraryFilm.transaction(requires_new: true) { LibraryFilm.insert_all!([ values ]) }
  end
end
