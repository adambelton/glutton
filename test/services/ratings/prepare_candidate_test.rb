require "test_helper"

class Ratings::PrepareCandidateTest < ActiveSupport::TestCase
  setup do
    @user = UserGuest.create!
    @film = Film.create!(title: "Selected film")
  end

  def prepare(**attributes)
    Ratings::PrepareCandidate.call(user_id: @user.id, film_id: @film.id, **attributes)
  end

  test "admission persists an unfinished candidate without a rating or event" do
    row = nil
    assert_no_difference [ "Rating.count", "DomainEvent.count", "LibraryFilm.count" ] do
      assert_difference "RatingFilm.count", 1 do
        row = prepare
      end
    end
    assert_equal [ row.id ], Ratings::NextCandidates.call(user_id: @user.id).map(&:id)
    assert_equal row.id, prepare.id
    assert_equal 1, RatingFilm.where(user: @user, film: @film).count
  end

  test "reopening preserves every combination of flags and original timestamps" do
    row = prepare
    [ false, true ].product([ false, true ]).each do |held, dismissed|
      row.update!(held:, dismissed:, created_at: 2.days.ago)
      assert_no_changes -> { row.reload.updated_at } do
        assert_equal row.id, prepare.id
      end
      assert_equal [ held, dismissed ], [ row.reload.held, row.dismissed ]
      assert_in_delta 2.days.ago, row.created_at, 1.second
    end
  end

  test "missing films and inactive or missing owners cannot admit candidates" do
    assert_no_difference "RatingFilm.count" do
      assert_raises(Ratings::FilmUnavailable) { prepare(film_id: Film.maximum(:id) + 1) }
      @user.update!(created_at: UserGuest::EXPIRY_DURATION.ago)
      assert_raises(Ratings::IdentityUnavailable) { prepare }
      @user.delete
      assert_raises(Ratings::IdentityUnavailable) { prepare }
    end
  end

  test "failed submission preserves admitted candidate while never creating another" do
    row = prepare
    assert_no_difference [ "RatingFilm.count", "Rating.count", "DomainEvent.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) do
        Ratings::SubmitRating.call(user_id: @user.id, rating_film_id: row.id, value: "invalid")
      end
      assert_raises(Ratings::FilmUnavailable) do
        Ratings::SubmitRating.call(user_id: @user.id, rating_film_id: row.id + 1, value: Rating::Values::BRILLIANT)
      end
    end
    assert_equal row.id, prepare.id
  end

  test "already rated entry is rejected by preparation without changing evidence" do
    row = prepare
    rating = Ratings::SubmitRating.call(user_id: @user.id, rating_film_id: row.id, value: Rating::Values::BRILLIANT)
    assert_no_difference [ "RatingFilm.count", "Rating.count", "DomainEvent.count" ] do
      assert_raises(Ratings::AlreadyRated) { prepare }
    end
    assert_equal rating.id, row.ratings.sole.id
  end
end
