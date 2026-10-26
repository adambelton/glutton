require "test_helper"

class Ratings::RevisionTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @user = UserGuest.create!
    @film = Film.create!(title: "Revised rating")
    @rating_film = RatingFilm.create!(user: @user, film: @film, dismissed: true, held: true)
    @original = Ratings::SubmitRating.call(user_id: @user.id, rating_film_id: @rating_film.id,
      value: Rating::Values::I_ENJOYED_THAT, expression_texts: [ "Original evidence" ])
  end

  def revise(**options)
    Ratings::ReviseRating.call(user_id: @user.id, rating_film_id: @rating_film.id,
      previous_rating_id: @original.id, value: Rating::Values::BRILLIANT,
      expression_texts: [ "  New evidence! É 👻  " ], **options)
  end

  test "successive replacements retain evidence without publishing events" do
    library_film = LibraryFilmWatched.create!(user: @user, film: @film)
    previous = @original
    original_expression_id = @original.rating_expressions.sole.id
    created_at = @rating_film.created_at
    Rating::Values::ALL.each do |value|
      replacement = nil
      assert_no_difference [ "LibraryFilm.count", "RatingFilm.count", "DomainEvent.count", "DomainEventStream.count" ] do
        assert_difference [ "Rating.count", "RatingExpression.count" ], 1 do
          replacement = revise(previous_rating_id: previous.id, value:)
        end
      end
      assert_not_equal previous.id, replacement.id
      assert_equal replacement.id, @rating_film.reload.current_rating.id
      assert_equal [ replacement.id ], @rating_film.ratings.current.pluck(:id)
      assert_equal value, replacement.reload.value
      assert_equal [ "  New evidence! É 👻  " ], replacement.rating_expressions.pluck(:text)
      previous = replacement
    end
    assert_equal Rating::Values::I_ENJOYED_THAT, @original.reload.value
    assert_equal original_expression_id, @original.rating_expressions.sole.id
    assert_equal "Original evidence", @original.rating_expressions.sole.text
    assert_equal LibraryFilm::RatingStatuses::RATED, library_film.rating_status
    assert_not library_film.can_rate?
    assert_equal 5, @rating_film.ratings.count
    assert @rating_film.reload.dismissed?
    assert @rating_film.held?
    assert_equal created_at, @rating_film.created_at
    assert_equal [ @rating_film.id ], RatingFilm.where(user: @user).rated.pluck(:id)
    assert_empty RatingFilm.where(user: @user).unrated
    assert_empty Ratings::NextCandidates.call(user_id: @user.id)
    assert_raises(Ratings::AlreadyRated) { @rating_film.submit_rating!(value: Rating::Values::GARBAGE) }
  end

  test "same value and omitted expressions are a full replacement" do
    replacement = Ratings::ReviseRating.call(user_id: @user.id, rating_film_id: @rating_film.id,
      previous_rating_id: @original.id, value: @original.value)
    assert_empty replacement.rating_expressions
    assert_equal @original.value, replacement.value
    assert_equal [ "Original evidence" ], @original.reload.rating_expressions.pluck(:text)
  end

  test "missing foreign removed and unrated candidates cannot be revised" do
    other = UserGuest.create!
    unrated = RatingFilm.create!(user: @user, film: Film.create!(title: "Unrated"))
    removed = RatingFilm.create!(user: @user, film: Film.create!(title: "Removed"))
    removed.destroy!
    assert_no_difference [ "Rating.count", "RatingExpression.count", "DomainEvent.count", "RatingFilm.count" ] do
      [ -1, removed.id ].each do |id|
        assert_raises(Ratings::FilmUnavailable) { revise(rating_film_id: id) }
      end
      assert_raises(Ratings::FilmUnavailable) { revise(user_id: other.id) }
      assert_raises(Ratings::RevisionUnavailable) { revise(rating_film_id: unrated.id) }
    end
    assert_equal @original.id, @rating_film.reload.current_rating.id
  end

  test "stale foreign and replayed previous IDs cannot overwrite the current rating" do
    other = RatingFilm.create!(user: @user, film: Film.create!(title: "Other rating"))
    foreign_rating = other.submit_rating!(value: Rating::Values::GARBAGE)
    [ -1, foreign_rating.id, nil ].each do |previous_rating_id|
      assert_raises(Ratings::StaleRating) { revise(previous_rating_id:) }
    end
    replacement = revise
    assert_no_difference [ "Rating.count", "RatingExpression.count", "DomainEvent.count" ] do
      assert_raises(Ratings::StaleRating) { revise }
    end
    assert_equal replacement.id, @rating_film.reload.current_rating.id
  end

  test "inactive and missing owners are rejected using fresh state" do
    deleted = UserDeleted.create!
    travel UserGuest::EXPIRY_DURATION
    assert_no_difference [ "Rating.count", "RatingExpression.count", "DomainEvent.count" ] do
      [ @user.id, deleted.id, -1 ].each do |user_id|
        assert_raises(Ratings::IdentityUnavailable) { revise(user_id:) }
      end
    end
    assert_equal @original.id, @rating_film.reload.current_rating.id
  end

  test "invalid replacements retain the current rating and leave transaction usable" do
    [ nil, "unknown", Rating::Values::BRILLIANT.to_sym ].each do |value|
      assert_raises(ActiveRecord::RecordInvalid) { revise(value:) }
      assert_equal @original.id, @rating_film.reload.current_rating.id
    end
    [ nil, "text", {}, [ nil ], [ 1 ], Array.new(Rating::MAX_EXPRESSIONS + 1, "text") ].each do |expression_texts|
      assert_raises(Ratings::InvalidExpressions) { revise(expression_texts:) }
      assert_equal @original.id, @rating_film.reload.current_rating.id
    end
    [ "", " \n", "é" * (RatingExpression::MAX_TEXT_LENGTH + 1) ].each do |text|
      assert_raises(ActiveRecord::RecordInvalid) { revise(expression_texts: [ "valid", text ]) }
    end
    assert_equal [ @original.id ], @rating_film.ratings.pluck(:id)
    assert_equal 1, DomainEvent.count
    assert_equal [ "Original evidence" ], @original.reload.rating_expressions.pluck(:text)
    assert_equal Rating::MAX_EXPRESSIONS, revise(expression_texts: Array.new(Rating::MAX_EXPRESSIONS, "é" * RatingExpression::MAX_TEXT_LENGTH)).rating_expressions.count
  end

  test "caller rollback preserves current rating and original stream sequence" do
    assert_no_difference [ "Rating.count", "RatingExpression.count", "DomainEvent.count" ] do
      Rating.transaction(requires_new: true) do
        revise
        raise ActiveRecord::Rollback
      end
    end
    assert_equal @original.id, @rating_film.reload.current_rating.id
    revise
    assert_equal [ 1 ], DomainEvent.order(:sequence).pluck(:sequence)
  end

  test "expression persistence failure preserves the current rating and all evidence" do
    connection = RatingExpression.connection
    connection.execute("ALTER TABLE rating_expressions ADD CONSTRAINT revision_test_expression CHECK (text <> 'blocked')")
    assert_no_difference [ "Rating.count", "RatingExpression.count", "DomainEvent.count" ] do
      assert_raises(ActiveRecord::StatementInvalid) { revise(expression_texts: [ "valid", "blocked" ]) }
    end
    assert_equal @original.id, @rating_film.reload.current_rating.id
    assert_equal [ "Original evidence" ], @original.rating_expressions.pluck(:text)
    assert_equal [ "valid" ], revise(expression_texts: [ "valid" ]).rating_expressions.pluck(:text)
  ensure
    connection&.execute("ALTER TABLE rating_expressions DROP CONSTRAINT IF EXISTS revision_test_expression")
  end

  test "domain errors use strict locale entries" do
    [ Ratings::RevisionUnavailable, Ratings::StaleRating ].each do |error|
      assert_equal I18n.t("ratings.errors.#{error.name.demodulize.underscore}", raise: true), error.new.message
    end
  end
end
