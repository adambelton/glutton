require "test_helper"

class RatingExpressionTest < ActiveSupport::TestCase
  setup do
    candidate = RatingFilm.create!(user: UserGuest.create!, film: Film.create!(title: "Expression storage"))
    @rating = candidate.submit_rating!(value: Rating::Values::BRILLIANT)
  end

  def insert(**attributes)
    RatingExpression.transaction(requires_new: true) do
      RatingExpression.insert_all!([ { rating_id: @rating.id, text: "Original" }.merge(attributes) ])
    end
  end

  test "database enforces references text and character length" do
    assert_raises(ActiveRecord::NotNullViolation) { insert(rating_id: nil) }
    assert_raises(ActiveRecord::InvalidForeignKey) { insert(rating_id: -1) }
    assert_raises(ActiveRecord::NotNullViolation) { insert(text: nil) }
    assert_raises(ActiveRecord::StatementInvalid) { insert(text: "é" * (RatingExpression::MAX_TEXT_LENGTH + 1)) }
    insert(text: "é" * RatingExpression::MAX_TEXT_LENGTH)
    assert_equal 1, @rating.rating_expressions.count
  end

  test "physical rating deletion cascades expressions" do
    insert
    @rating.delete
    assert_not RatingExpression.where(rating_id: @rating.id).exists?
  end

  test "validation and boundary failures use localized messages" do
    expression = RatingExpression.new
    assert_not expression.valid?
    assert_includes expression.errors.full_messages, "Rating must exist"
    assert_includes expression.errors.full_messages, "Expression can't be blank"
    expression.text = "x" * (RatingExpression::MAX_TEXT_LENGTH + 1)
    assert_not expression.valid?
    assert expression.errors.of_kind?(:text, :too_long)
    assert_equal I18n.t("ratings.errors.invalid_expressions", count: Rating::MAX_EXPRESSIONS, raise: true), Ratings::InvalidExpressions.new.message
  end
end
