require "test_helper"

class Ratings::RevisionTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "Revised rating")
    @rating_film = Ratings::RatingFilm.create!(user: @user, film: @film, dismissed: true, held: true)
    @original = Ratings::SubmitRating.call(user_id: @user.id, rating_film_id: @rating_film.id,
      value: Ratings::Rating::Values::PRETTY_GOOD, notes: "Original evidence")
  end

  def revise(**options)
    Ratings::ReviseRating.call(user_id: @user.id, rating_film_id: @rating_film.id,
      previous_rating_id: @original.id, value: Ratings::Rating::Values::BRILLIANT,
      notes: "  New evidence! É 👻  ", **options)
  end

  test "successive replacements retain evidence without publishing events" do
    library_film = Library::LibraryFilmWatched.create!(user: @user, film: @film)
    previous = @original
    original_expression_id = @original.id
    created_at = @rating_film.created_at
    Ratings::Rating::Values::ALL.each do |value|
      replacement = nil
      assert_no_difference [ "Library::LibraryFilm.count", "Ratings::RatingFilm.count", "DomainEvents::DomainEvent.count", "DomainEvents::DomainEventStream.count" ] do
        assert_difference "Ratings::Rating.count", 1 do
          replacement = revise(previous_rating_id: previous.id, value:)
        end
      end
      assert_not_equal previous.id, replacement.id
      assert_equal replacement.id, @rating_film.reload.current_rating.id
      assert_equal [ replacement.id ], @rating_film.ratings.current.pluck(:id)
      assert_equal value, replacement.reload.value
      assert_equal "  New evidence! É 👻  ", replacement.notes
      previous = replacement
    end
    assert_equal Ratings::Rating::Values::PRETTY_GOOD, @original.reload.value
    assert_equal original_expression_id, @original.id
    assert_equal "Original evidence", @original.notes
    assert_equal Library::LibraryFilm::RatingStatuses::RATED, library_film.rating_status
    assert_not library_film.can_rate?
    assert_equal 5, @rating_film.ratings.count
    assert @rating_film.reload.dismissed?
    assert @rating_film.held?
    assert_equal created_at, @rating_film.created_at
    assert_equal [ @rating_film.id ], Ratings::RatingFilm.where(user: @user).rated.pluck(:id)
    assert_empty Ratings::RatingFilm.where(user: @user).unrated
    assert_empty Ratings::NextCandidates.call(user_id: @user.id)
    assert_raises(Ratings::AlreadyRated) { @rating_film.submit_rating!(value: Ratings::Rating::Values::GARBAGE) }
  end

  test "same value and omitted expressions are a full replacement" do
    replacement = Ratings::ReviseRating.call(user_id: @user.id, rating_film_id: @rating_film.id,
      previous_rating_id: @original.id, value: @original.value)
    assert_nil replacement.notes
    assert_equal @original.value, replacement.value
    assert_equal "Original evidence", @original.reload.notes
  end

  test "missing foreign removed and unrated candidates cannot be revised" do
    other = Identity::UserGuest.create!
    unrated = Ratings::RatingFilm.create!(user: @user, film: Registry::Film.create!(title: "Unrated"))
    removed = Ratings::RatingFilm.create!(user: @user, film: Registry::Film.create!(title: "Removed"))
    removed.destroy!
    assert_no_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count", "Ratings::RatingFilm.count" ] do
      [ -1, removed.id ].each do |id|
        assert_raises(Ratings::FilmUnavailable) { revise(rating_film_id: id) }
      end
      assert_raises(Ratings::FilmUnavailable) { revise(user_id: other.id) }
      assert_raises(Ratings::RevisionUnavailable) { revise(rating_film_id: unrated.id) }
    end
    assert_equal @original.id, @rating_film.reload.current_rating.id
  end

  test "stale foreign and replayed previous IDs cannot overwrite the current rating" do
    other = Ratings::RatingFilm.create!(user: @user, film: Registry::Film.create!(title: "Other rating"))
    foreign_rating = other.submit_rating!(value: Ratings::Rating::Values::GARBAGE)
    [ -1, foreign_rating.id, nil ].each do |previous_rating_id|
      assert_raises(Ratings::StaleRating) { revise(previous_rating_id:) }
    end
    replacement = revise
    assert_no_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      assert_raises(Ratings::StaleRating) { revise }
    end
    assert_equal replacement.id, @rating_film.reload.current_rating.id
  end

  test "inactive and missing owners are rejected using fresh state" do
    deleted = Identity::UserDeleted.create!
    travel Identity::UserGuest::EXPIRY_DURATION
    assert_no_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      [ @user.id, deleted.id, -1 ].each do |user_id|
        assert_raises(Ratings::IdentityUnavailable) { revise(user_id:) }
      end
    end
    assert_equal @original.id, @rating_film.reload.current_rating.id
  end

  test "invalid replacements retain the current rating and leave transaction usable" do
    [ nil, "unknown", Ratings::Rating::Values::BRILLIANT.to_sym ].each do |value|
      assert_raises(ActiveRecord::RecordInvalid) { revise(value:) }
      assert_equal @original.id, @rating_film.reload.current_rating.id
    end
    [ {}, [ "text" ], :text ].each do |notes|
      assert_raises(Ratings::InvalidNotes) { revise(notes:) }
      assert_equal @original.id, @rating_film.reload.current_rating.id
    end
    maximum = "é" * Ratings::Rating::MAX_NOTES_LENGTH
    assert_raises(ActiveRecord::RecordInvalid) { revise(notes: maximum + "é") }
    assert_equal [ @original.id ], @rating_film.ratings.pluck(:id)
    assert_equal 1, DomainEvents::DomainEvent.count
    assert_equal "Original evidence", @original.reload.notes
    assert_equal maximum, revise(notes: maximum).notes
  end

  test "caller rollback preserves current rating and original stream sequence" do
    assert_no_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      Ratings::Rating.transaction(requires_new: true) do
        revise
        raise ActiveRecord::Rollback
      end
    end
    assert_equal @original.id, @rating_film.reload.current_rating.id
    revise
    assert_equal [ 1 ], DomainEvents::DomainEvent.order(:sequence).pluck(:sequence)
  end

  test "expression persistence failure preserves the current rating and all evidence" do
    connection = Ratings::Rating.lease_connection
    connection.execute("ALTER TABLE ratings ADD CONSTRAINT revision_test_expression CHECK (notes <> 'blocked')")
    assert_no_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      assert_raises(ActiveRecord::StatementInvalid) { revise(notes: "blocked") }
    end
    assert_equal @original.id, @rating_film.reload.current_rating.id
    assert_equal "Original evidence", @original.notes
    assert_equal "valid", revise(notes: "valid").notes
  ensure
    connection&.execute("ALTER TABLE ratings DROP CONSTRAINT IF EXISTS revision_test_expression")
  end

  test "domain errors use strict locale entries" do
    [ Ratings::RevisionUnavailable, Ratings::StaleRating ].each do |error|
      assert_equal I18n.t("ratings.errors.#{error.name.demodulize.underscore}", raise: true), error.new.message
    end
  end
end
