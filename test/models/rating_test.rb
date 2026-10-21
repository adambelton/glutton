require "test_helper"

class RatingTest < ActiveSupport::TestCase
  setup do
    @user = UserGuest.create!
    @rating_film = candidate
  end

  def candidate(**attributes)
    RatingFilm.create!(user: @user, film: Film.create!(title: "Rating model"), **attributes)
  end

  def insert(**attributes)
    Rating.transaction(requires_new: true) do
      Rating.insert_all!([ { rating_film_id: @rating_film.id, value: Rating::Values::ENJOYED }.merge(attributes) ])
    end
  end

  test "database enforces required reference allowed choices and one first submission" do
    assert_raises(ActiveRecord::NotNullViolation) { insert(rating_film_id: nil) }
    assert_raises(ActiveRecord::InvalidForeignKey) { insert(rating_film_id: -1) }
    assert_raises(ActiveRecord::NotNullViolation) { insert(value: nil) }
    assert_raises(ActiveRecord::StatementInvalid) { insert(value: "unknown") }
    insert
    assert_raises(ActiveRecord::RecordNotUnique) { insert(value: Rating::Values::BRILLIANT) }
  end

  test "candidate owns submission permission and action independently of dismissal" do
    assert @rating_film.can_submit_rating?
    @rating_film.dismiss!
    rating = @rating_film.submit_rating!(value: Rating::Values::GARBAGE)
    assert_equal @rating_film.id, rating.rating_film_id
    assert_not @rating_film.can_submit_rating?
    assert_raises(Ratings::AlreadyRated) { @rating_film.submit_rating!(value: Rating::Values::ENJOYED) }
  end

  test "scopes compose over rating existence and dismissal with stable bounded selection" do
    freeze_time
    unrated = @rating_film
    dismissed = candidate(dismissed: true)
    rated = candidate
    rated_dismissed = candidate(dismissed: true)
    [ rated, rated_dismissed ].each { |row| row.submit_rating!(value: Rating::Values::BRILLIANT) }
    foreign = candidate(user: UserGuest.create!)
    travel 1.hour
    newest = candidate
    owned = RatingFilm.where(user: @user)
    assert_equal [ rated.id, rated_dismissed.id ], owned.rated.order(:id).pluck(:id)
    assert_equal [ unrated.id, dismissed.id, newest.id ], owned.unrated.order(:id).pluck(:id)
    assert_equal [ dismissed.id, rated_dismissed.id ], owned.dismissed.order(:id).pluck(:id)
    assert_equal [ rated_dismissed.id ], owned.rated.dismissed.pluck(:id)
    assert_equal [ dismissed.id ], owned.unrated.dismissed.pluck(:id)
    assert_equal [ unrated.id, newest.id ], owned.pending.order(:id).pluck(:id)
    assert_includes RatingFilm.unrated.pluck(:id), foreign.id
    assert_equal [ unrated.id ], Ratings::NextCandidates.call(user_id: @user.id, limit: 1).map(&:id)
    assert_equal [ unrated.id, newest.id ], Ratings::NextCandidates.call(user_id: @user.id).map(&:id)
  end

  test "choice labels and validation and duplicate errors render with strict translations" do
    assert_equal :strict, Rails.application.config.i18n.raise_on_missing_translations
    labels = [ "Brilliant", "I Enjoyed That", "Not For Me", "Garbage" ]
    assert_equal labels, Rating::Values::ALL.map { |value| I18n.t("ratings.values.#{value}", raise: true) }
    rating = Rating.new
    assert_not rating.valid?
    assert_includes rating.errors.full_messages, "Rating film must exist"
    assert_includes rating.errors.full_messages, "Rating is not included in the list"
    assert_equal I18n.t("ratings.errors.already_rated", raise: true), Ratings::AlreadyRated.new.message
  end
end
