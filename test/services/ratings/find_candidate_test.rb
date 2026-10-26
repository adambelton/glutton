require "test_helper"

class Ratings::FindCandidateTest < ActiveSupport::TestCase
  setup do
    @user = UserGuest.create!
    @film = Film.create!(title: "Candidate lookup")
    @candidate = RatingFilm.create!(user: @user, film: @film, held: true, dismissed: true)
  end

  def find(**attributes)
    Ratings::FindCandidate.call(user_id: @user.id, rating_film_id: @candidate.id, **attributes)
  end

  test "reads an existing owned candidate without changing its exclusion state" do
    assert_no_difference [ "RatingFilm.count", "Rating.count", "DomainEvent.count" ] do
      assert_no_changes -> { @candidate.reload.updated_at } do
        row = find
        assert_equal @candidate.id, row.id
        assert row.held?
        assert row.dismissed?
      end
    end
  end

  test "foreign deleted and missing candidates are unavailable without admission" do
    other = UserGuest.create!
    assert_no_difference "RatingFilm.count" do
      assert_raises(Ratings::FilmUnavailable) { find(user_id: other.id) }
      assert_raises(Ratings::FilmUnavailable) { find(rating_film_id: @candidate.id + 1) }
    end
    @candidate.destroy!
    assert_raises(Ratings::FilmUnavailable) { find }
    assert_empty RatingFilm.where(user: @user)
  end

  test "fresh inactive or missing identity cannot load candidate" do
    @user.update!(created_at: UserGuest::EXPIRY_DURATION.ago)
    assert_raises(Ratings::IdentityUnavailable) { find }
    @user.delete
    assert_raises(Ratings::IdentityUnavailable) { find }
  end
end
