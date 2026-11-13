require "test_helper"

class Library::LibraryFilmTest < ActiveSupport::TestCase
  setup do
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "Library model film")
  end

  def attributes
    { user_id: @user.id, film_id: @film.id }
  end

  test "watched entries preserve relationship uniqueness" do
    row = Library::LibraryFilm.create!(attributes.merge(watched: true))
    loaded = Library::LibraryFilm.find(row.id)
    assert_equal row, loaded
    duplicate = Library::LibraryFilm.new(attributes.merge(watched: true))
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:film_id, :taken)
    assert Library::LibraryFilm.create!(attributes.merge(user: Identity::UserGuest.create!).merge(watched: true)).persisted?
    assert_raises(ActiveRecord::RecordNotUnique) { insert(attributes.merge(watched: true)) }
  end

  test "collection action guards reflect the entry's lifecycle" do
    entry = Library::LibraryFilm.new(attributes)
    assert entry.can_add_to_watchlist?
    assert entry.can_add_to_watched?
    assert_not entry.can_move_to_watched?
    assert_not entry.can_move_to_watchlist?
    assert_not entry.can_remove_from_watchlist?
    assert_not entry.can_remove_from_watched?

    entry.add_to_watchlist!
    assert_not entry.can_add_to_watchlist?
    assert_not entry.can_add_to_watched?
    assert entry.can_move_to_watched?
    assert entry.can_remove_from_watchlist?
    assert_not entry.can_move_to_watchlist?
    assert_not entry.can_remove_from_watched?

    entry.move_to_watched!
    assert_not entry.can_move_to_watched?
    assert_not entry.can_remove_from_watchlist?
    assert entry.can_move_to_watchlist?
    assert entry.can_remove_from_watched?

    entry.remove_from_watched!
    assert_not entry.can_add_to_watchlist?
    assert_not entry.can_add_to_watched?
  end

  test "watchlist is the default and watched cannot be null" do
    assert_not Library::LibraryFilm.new(attributes).watched?
    assert_raises(ActiveRecord::NotNullViolation) { insert(attributes.merge(watched: nil)) }
  end

  test "foreign keys require real owners and films and preserve referenced films" do
    assert_raises(ActiveRecord::InvalidForeignKey) { insert(attributes.merge(watched: true, user_id: Identity::User.maximum(:id) + 1)) }
    assert_raises(ActiveRecord::InvalidForeignKey) { insert(attributes.merge(watched: true, film_id: Registry::Film.maximum(:id) + 1)) }
    Library::LibraryFilm.create!(attributes.merge(watched: true))
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Registry::Film.transaction(requires_new: true) { @film.destroy! }
    end
    assert Registry::Film.exists?(@film.id)
  end

  test "validation messages resolve through English locales with strict translation checks" do
    assert_equal :strict, Rails.application.config.i18n.raise_on_missing_translations
    I18n.with_locale(:en) do
      row = Library::LibraryFilm.new(watched: true)
      row.valid?
      assert_includes row.errors.full_messages, "User must exist"
      assert_includes row.errors.full_messages, "Film must exist"
    end
  end

  test "rating editing requires watched and the owners rating evidence" do
    row = Library::LibraryFilm.create!(attributes.merge(watched: true))
    assert_not row.can_edit_rating?
    foreign = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film: @film)
    foreign.submit_rating!(value: Ratings::Rating::Values::BRILLIANT)
    assert_not row.can_edit_rating?
    candidate = Ratings::RatingFilm.create!(user: @user, film: @film, suppressed: true, dismissed: true)
    assert_not row.can_edit_rating?
    candidate.submit_rating!(value: Ratings::Rating::Values::BRILLIANT)
    assert row.can_edit_rating?
    assert_not Library::LibraryFilm.new(attributes).can_edit_rating?
  end

  private

  def insert(values)
    Library::LibraryFilm.transaction(requires_new: true) { Library::LibraryFilm.insert_all!([ values ]) }
  end
end
