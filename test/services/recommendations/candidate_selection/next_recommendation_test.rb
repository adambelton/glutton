require "test_helper"
require_relative "../../../support/assessed_recommendation_films"

class Recommendations::NextRecommendationTest < ActiveSupport::TestCase
  include AssessedRecommendationFilms

  test "records from suppression alone do not skip ranking and the exclusion applies to admission" do
    user = Identity::UserGuest.create!
    first = Registry::Film.create!(title: "First ranked")
    second = Registry::Film.create!(title: "Second ranked")
    suppression_only = Recommendations::RecommendationFilm.new(user:, film: second)
    suppression_only.suppress!

    assert_no_difference "Recommendations::RecommendationFilm.count" do
      result = Recommendations::CandidateSelection::NextRecommendation.call(user_id: user.id)
      assert_not result.unlocked?
      assert_nil result.recommendation_film
    end

    unlock_recommendations_for(user:)
    result = Recommendations::CandidateSelection::NextRecommendation.call(user_id: user.id)
    assert_equal first.id, result.recommendation_film.film_id
    assert_predicate result.recommendation_film.recommended_at, :present?
    assert_nil suppression_only.reload.recommended_at

    assert_equal :processed, suppression_only.discard_suppression_only_record!
    assert_not Recommendations::RecommendationFilm.exists?(suppression_only.id)

    assert_difference "Recommendations::RecommendationFilm.count", 1 do
      result = Recommendations::CandidateSelection::NextRecommendation.call(user_id: user.id, excluding_film_id: first.id)
      assert_equal second.id, result.recommendation_film.film_id
      assert_predicate result.recommendation_film.recommended_at, :present?
    end
  end
end
