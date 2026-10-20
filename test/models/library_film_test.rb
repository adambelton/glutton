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

  test "base and unsupported rows are rejected" do
    base = LibraryFilm.new(attributes)
    assert_not base.valid?
    assert base.errors.of_kind?(:type, :inclusion)
    [ nil, "LibraryFilm", "LibraryFilmToWatch" ].each do |type|
      assert_raises(ActiveRecord::StatementInvalid) { insert(attributes.merge(type:)) }
    end
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
      base = LibraryFilm.new(attributes)
      base.valid?
      assert_includes base.errors.full_messages, "Library classification is not included in the list"
    end
  end

  private

  def insert(values)
    LibraryFilm.transaction(requires_new: true) { LibraryFilm.insert_all!([ values ]) }
  end
end
