require "test_helper"

class RatingPersistenceTest < ActiveSupport::TestCase
  setup do
    @user = UserGuest.create!
    @film = Film.create!(title: "Ratings persistence")
    @rating_film = RatingFilm.create!(user: @user, film: @film)
  end

  def insert(attributes)
    RatingFilm.transaction(requires_new: true) { RatingFilm.insert_all!([ attributes ]) }
  end

  def film_attributes
    { user_id: @user.id, film_id: @film.id }
  end

  test "queue requires real references and unique user film" do
    assert_raises(ActiveRecord::RecordNotUnique) { insert(film_attributes) }
    [ :user_id, :film_id ].each do |field|
      assert_raises(ActiveRecord::NotNullViolation) { insert(film_attributes.merge(field => nil)) }
      assert_raises(ActiveRecord::InvalidForeignKey) { insert(film_attributes.merge(field => -1)) }
    end
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Film.transaction(requires_new: true) { @film.destroy! }
    end
    duplicate = RatingFilm.new(film_attributes)
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:film_id, :taken)
  end

  test "dismissal defaults false and cannot be null in model or database" do
    assert_not @rating_film.dismissed?
    other = Film.create!(title: "Other candidate")
    insert(film_attributes.merge(film_id: other.id))
    assert_not RatingFilm.find_by!(film: other).dismissed?
    @rating_film.dismissed = nil
    assert_not @rating_film.valid?
    assert_raises(ActiveRecord::NotNullViolation) do
      RatingFilm.transaction(requires_new: true) { @rating_film.save!(validate: false) }
    end
  end

  test "dismissal scopes reflect persisted state and model owns duplicate rejection" do
    second = RatingFilm.create!(user: @user, film: Film.create!(title: "Second candidate"))
    assert @rating_film.can_dismiss?
    @rating_film.dismiss!
    assert_not @rating_film.can_dismiss?
    assert_raises(Ratings::DismissalUnavailable) { @rating_film.dismiss! }
    assert_equal [ @rating_film.id ], RatingFilm.where(user: @user).dismissed.pluck(:id)
    assert_equal [ second.id ], RatingFilm.where(user: @user).pending.pluck(:id)
  end

  test "validation and domain errors render English under strict translation checks" do
    assert_equal :strict, Rails.application.config.i18n.raise_on_missing_translations
    empty = RatingFilm.new(dismissed: nil)
    empty.valid?
    assert_includes empty.errors.full_messages, "User must exist"
    assert_includes empty.errors.full_messages, "Film must exist"
    assert_includes empty.errors.full_messages, "Dismissed is not included in the list"
    [ Ratings::IdentityUnavailable, Ratings::FilmUnavailable, Ratings::DismissalUnavailable ].each do |error|
      assert_equal I18n.t("ratings.errors.#{error.name.demodulize.underscore}", raise: true), error.new.message
    end
  end
end
