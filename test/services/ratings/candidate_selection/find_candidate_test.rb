require "test_helper"

class Ratings::FindCandidateTest < ActiveSupport::TestCase
  setup do
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "Candidate lookup")
    @candidate = Ratings::RatingFilm.create!(user: @user, film: @film, suppressed: true, dismissed: true)
  end

  def find(**attributes)
    Ratings::CandidateSelection::FindCandidate.call(user_id: @user.id, rating_film_id: @candidate.id, **attributes)
  end

  test "reads an existing owned candidate without changing its exclusion state" do
    assert_no_difference [ "Ratings::RatingFilm.count", "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      assert_no_changes -> { @candidate.reload.updated_at } do
        row = find
        assert_equal @candidate.id, row.id
        assert row.suppressed?
        assert row.dismissed?
      end
    end
  end

  test "foreign deleted and missing candidates are unavailable without admission" do
    other = Identity::UserGuest.create!
    assert_no_difference "Ratings::RatingFilm.count" do
      assert_raises(Ratings::Errors::FilmUnavailable) { find(user_id: other.id) }
      assert_raises(Ratings::Errors::FilmUnavailable) { find(rating_film_id: @candidate.id + 1) }
    end
    @candidate.destroy!
    assert_raises(Ratings::Errors::FilmUnavailable) { find }
    assert_empty Ratings::RatingFilm.where(user: @user)
  end

  test "fresh inactive or missing identity cannot load candidate" do
    travel Identity::UserGuest::EXPIRY_DURATION + 1.second do
      assert_raises(Identity::Errors::Unavailable) { find }
    end
    assert_raises(Identity::Errors::Unavailable) { find(user_id: -1) }
  end
end
