require "test_helper"

class Ratings::RatingHoldTest < ActiveSupport::TestCase
  setup do
    @row = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film: Registry::Film.create!(title: "Hold"))
  end

  test "hold and release are explicit model actions independent of dismissal" do
    assert_not @row.held?
    assert_raises(Ratings::Errors::HoldReleaseUnavailable) { @row.release_hold! }
    @row.dismiss!
    @row.hold!
    assert @row.reload.held?
    assert_raises(Ratings::Errors::HoldUnavailable) { @row.hold! }
    @row.release_hold!
    assert_not @row.reload.held?
    assert @row.dismissed?
    assert_raises(Ratings::Errors::DismissalUnavailable) { @row.dismiss! }
  end

  test "held is a required boolean in validation and storage" do
    @row.held = nil
    assert_not @row.valid?
    assert @row.errors.of_kind?(:held, :inclusion)
    assert_raises(ActiveRecord::NotNullViolation) do
      Ratings::RatingFilm.transaction(requires_new: true) { @row.update_columns(held: nil) }
    end
    assert_equal "Held", Ratings::RatingFilm.human_attribute_name(:held)
    assert_equal I18n.t("ratings.errors.hold_unavailable", raise: true), Ratings::Errors::HoldUnavailable.new.message
    assert_equal I18n.t("ratings.errors.hold_release_unavailable", raise: true), Ratings::Errors::HoldReleaseUnavailable.new.message
  end

  test "explicit rating preserves held and dismissed until asynchronous reaction" do
    @row.hold!
    @row.dismiss!
    Ratings::RatingRecording::SubmitRating.call(user_id: @row.user_id, rating_film_id: @row.id, value: Ratings::Rating::Values::BRILLIANT)
    assert @row.reload.held?
    assert @row.dismissed?
    assert_not Ratings::RatingFilm.pending.exists?(@row.id)
  end
end
