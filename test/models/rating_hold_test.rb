require "test_helper"

class RatingHoldTest < ActiveSupport::TestCase
  setup do
    @row = RatingFilm.create!(user: UserGuest.create!, film: Film.create!(title: "Hold"))
  end

  test "hold and release are explicit model actions independent of dismissal" do
    assert_not @row.held?
    assert_raises(Ratings::HoldReleaseUnavailable) { @row.release_hold! }
    @row.dismiss!
    @row.hold!
    assert @row.reload.held?
    assert_raises(Ratings::HoldUnavailable) { @row.hold! }
    @row.release_hold!
    assert_not @row.reload.held?
    assert @row.dismissed?
    assert_raises(Ratings::DismissalUnavailable) { @row.dismiss! }
  end

  test "held is a required boolean in validation and storage" do
    @row.held = nil
    assert_not @row.valid?
    assert @row.errors.of_kind?(:held, :inclusion)
    assert_raises(ActiveRecord::NotNullViolation) do
      RatingFilm.transaction(requires_new: true) { @row.update_columns(held: nil) }
    end
    assert_equal "Held", RatingFilm.human_attribute_name(:held)
    assert_equal I18n.t("ratings.errors.hold_unavailable", raise: true), Ratings::HoldUnavailable.new.message
    assert_equal I18n.t("ratings.errors.hold_release_unavailable", raise: true), Ratings::HoldReleaseUnavailable.new.message
  end

  test "explicit rating preserves held and dismissed until asynchronous reaction" do
    @row.update!(held: true, dismissed: true)
    Ratings::SubmitRating.call(user_id: @row.user_id, rating_film_id: @row.id, value: Rating::Values::BRILLIANT)
    assert @row.reload.held?
    assert @row.dismissed?
    assert_not RatingFilm.pending.exists?(@row.id)
  end
end
