require "test_helper"

class Ratings::RatingSuppressionTest < ActiveSupport::TestCase
  setup do
    @row = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film: Registry::Film.create!(title: "Hold"))
  end

  test "hold and release are explicit model actions independent of dismissal" do
    assert_not @row.suppressed?
    assert_raises(Ratings::Errors::SuppressionReleaseUnavailable) { @row.release_suppression! }
    @row.dismiss!
    @row.suppress!
    assert @row.reload.suppressed?
    assert_raises(Ratings::Errors::SuppressionUnavailable) { @row.suppress! }
    @row.release_suppression!
    assert_not @row.reload.suppressed?
    assert @row.dismissed?
    assert_raises(Ratings::Errors::DismissalUnavailable) { @row.dismiss! }
  end

  test "suppressed is a required boolean in validation and storage" do
    @row.suppressed = nil
    assert_not @row.valid?
    assert @row.errors.of_kind?(:suppressed, :inclusion)
    assert_raises(ActiveRecord::NotNullViolation) do
      Ratings::RatingFilm.transaction(requires_new: true) { @row.update_columns(suppressed: nil) }
    end
    assert_equal "Suppressed", Ratings::RatingFilm.human_attribute_name(:suppressed)
    assert_equal I18n.t("ratings.errors.suppression_unavailable", raise: true), Ratings::Errors::SuppressionUnavailable.new.message
    assert_equal I18n.t("ratings.errors.suppression_release_unavailable", raise: true), Ratings::Errors::SuppressionReleaseUnavailable.new.message
  end

  test "explicit rating preserves suppressed and dismissed until asynchronous reaction" do
    @row.suppress!
    @row.dismiss!
    Ratings::RatingRecording::SubmitRating.call(user_id: @row.user_id, rating_film_id: @row.id, value: Ratings::Rating::Values::BRILLIANT)
    assert @row.reload.suppressed?
    assert @row.dismissed?
    assert_not Ratings::RatingFilm.pending.exists?(@row.id)
  end
end
