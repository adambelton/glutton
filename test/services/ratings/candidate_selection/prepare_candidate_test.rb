require "test_helper"

class Ratings::PrepareCandidateTest < ActiveSupport::TestCase
  setup do
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "Selected film")
  end

  def prepare(**attributes)
    Ratings::CandidateSelection::PrepareCandidate.call(user_id: @user.id, film_id: @film.id, **attributes)
  end

  test "admission persists an unfinished candidate without a rating or event" do
    row = nil
    assert_no_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count", "Library::LibraryFilm.count" ] do
      assert_difference "Ratings::RatingFilm.count", 1 do
        row = prepare
      end
    end
    assert_equal [ row.id ], Ratings::CandidateSelection::NextCandidates.call(user_id: @user.id).map(&:id)
    assert_equal row.id, prepare.id
    assert_equal 1, Ratings::RatingFilm.where(user: @user, film: @film).count
  end

  test "reopening preserves every combination of flags and original timestamps" do
    row = Ratings::RatingFilm.create!(user: @user, film: @film, created_at: 2.days.ago)
    [
      [ -> { }, false, false ],
      [ -> { row.hold! }, true, false ],
      [ -> { row.dismiss! }, true, true ],
      [ -> { row.release_hold! }, false, true ]
    ].each do |arrange, held, dismissed|
      arrange.call
      assert_no_changes -> { row.reload.updated_at } do
        assert_equal row.id, prepare.id
      end
      assert_equal [ held, dismissed ], [ row.reload.held, row.dismissed ]
      assert_in_delta 2.days.ago, row.created_at, 1.second
    end
  end

  test "missing films and inactive or missing owners cannot admit candidates" do
    assert_no_difference "Ratings::RatingFilm.count" do
      assert_raises(Ratings::Errors::FilmUnavailable) { prepare(film_id: Registry::Film.maximum(:id) + 1) }
      travel Identity::UserGuest::EXPIRY_DURATION + 1.second do
        assert_raises(Identity::Errors::Unavailable) { prepare }
      end
      assert_raises(Identity::Errors::Unavailable) { prepare(user_id: -1) }
    end
  end

  test "failed submission preserves admitted candidate while never creating another" do
    row = prepare
    assert_no_difference [ "Ratings::RatingFilm.count", "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) do
        Ratings::RatingRecording::SubmitRating.call(user_id: @user.id, rating_film_id: row.id, value: "invalid")
      end
      assert_raises(Ratings::Errors::FilmUnavailable) do
        Ratings::RatingRecording::SubmitRating.call(user_id: @user.id, rating_film_id: row.id + 1, value: Ratings::Rating::Values::BRILLIANT)
      end
    end
    assert_equal row.id, prepare.id
  end

  test "already rated entry is rejected by preparation without changing evidence" do
    row = prepare
    rating = Ratings::RatingRecording::SubmitRating.call(user_id: @user.id, rating_film_id: row.id, value: Ratings::Rating::Values::BRILLIANT)
    assert_no_difference [ "Ratings::RatingFilm.count", "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      assert_raises(Ratings::Errors::AlreadyRated) { prepare }
    end
    assert_equal rating.id, row.ratings.sole.id
  end
end
