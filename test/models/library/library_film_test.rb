require "test_helper"

class Library::LibraryFilmTest < ActiveSupport::TestCase
  setup do
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "Library model film")
  end

  def attributes
    { user_id: @user.id, film_id: @film.id }
  end

  test "watched subtype uses default STI mapping and shared relationship uniqueness" do
    row = Library::LibraryFilmWatched.create!(attributes)
    loaded = Library::LibraryFilm.find(row.id)
    assert_equal row, loaded
    duplicate = Library::LibraryFilmWatched.new(attributes)
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:film_id, :taken)
    assert Library::LibraryFilmWatched.create!(attributes.merge(user: Identity::UserGuest.create!)).persisted?
    assert_raises(ActiveRecord::RecordNotUnique) { insert(attributes.merge(type: "LibraryFilmWatched")) }
  end

  test "watch permission defaults to denied and to-watch entries permit it" do
    assert_not Library::LibraryFilmWatched.new.can_watch?
    assert Library::LibraryFilmToWatch.new.can_watch?
  end

  test "watchlist addition error is present only when the action is denied" do
    assert_nil Library::LibraryFilmNotInterested.new.watchlist_addition_error
    assert_equal Library::WatchlistUnavailable, Library::LibraryFilmToWatch.new.watchlist_addition_error
    assert_equal Library::WatchlistUnavailable, Library::LibraryFilmWatched.new.watchlist_addition_error
  end

  test "dismissal permission and error agree for supported entries" do
    assert Library::LibraryFilmToWatch.new.can_mark_not_interested?
    assert_nil Library::LibraryFilmToWatch.new.dismissal_error
    assert_not Library::LibraryFilmWatched.new.can_mark_not_interested?
    assert_equal Library::DismissalUnavailable, Library::LibraryFilmWatched.new.dismissal_error
    assert_not Library::LibraryFilmNotInterested.new.can_mark_not_interested?
    assert_equal Library::DismissalUnavailable, Library::LibraryFilmNotInterested.new.dismissal_error
  end

  test "subtypes share one user-film relationship" do
    Library::LibraryFilmToWatch.create!(attributes)
    duplicate = Library::LibraryFilmWatched.new(attributes)
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:film_id, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) { insert(attributes.merge(type: "LibraryFilmWatched")) }
  end

  test "root construction is prohibited while subtype construction and loading work" do
    assert_raises(NotImplementedError) { Library::LibraryFilm.new(attributes) }
    assert_raises(NotImplementedError) { Library::LibraryFilm.create!(attributes) }
    row = Library::LibraryFilmWatched.create!(attributes)
    assert_equal row, Library::LibraryFilm.find(row.id)
    assert_raises(ActiveRecord::NotNullViolation) { insert(attributes.merge(type: nil)) }
  end

  test "foreign keys require real owners and films and preserve referenced films" do
    assert_raises(ActiveRecord::InvalidForeignKey) { insert(attributes.merge(type: "LibraryFilmWatched", user_id: Identity::User.maximum(:id) + 1)) }
    assert_raises(ActiveRecord::InvalidForeignKey) { insert(attributes.merge(type: "LibraryFilmWatched", film_id: Registry::Film.maximum(:id) + 1)) }
    Library::LibraryFilmWatched.create!(attributes)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Registry::Film.transaction(requires_new: true) { @film.destroy! }
    end
    assert Registry::Film.exists?(@film.id)
  end

  test "validation messages resolve through English locales with strict translation checks" do
    assert_equal :strict, Rails.application.config.i18n.raise_on_missing_translations
    I18n.with_locale(:en) do
      row = Library::LibraryFilmWatched.new
      row.valid?
      assert_includes row.errors.full_messages, "User must exist"
      assert_includes row.errors.full_messages, "Film must exist"
    end
  end

  test "rating editing requires watched and the owners rating evidence" do
    row = Library::LibraryFilmWatched.create!(attributes)
    assert_not row.can_edit_rating?
    foreign = RatingFilm.create!(user: Identity::UserGuest.create!, film: @film)
    foreign.submit_rating!(value: Rating::Values::BRILLIANT)
    assert_not row.can_edit_rating?
    candidate = RatingFilm.create!(user: @user, film: @film, held: true, dismissed: true)
    assert_not row.can_edit_rating?
    candidate.submit_rating!(value: Rating::Values::BRILLIANT)
    assert row.can_edit_rating?
    assert_not Library::LibraryFilmToWatch.new(attributes).can_edit_rating?
    assert_not Library::LibraryFilmNotInterested.new(attributes).can_edit_rating?
  end

  private

  def insert(values)
    Library::LibraryFilm.transaction(requires_new: true) { Library::LibraryFilm.insert_all!([ values ]) }
  end
end
