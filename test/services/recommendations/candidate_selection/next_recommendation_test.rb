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

  test "match follows current signed points while an admitted film stays in the queue" do
    user = Identity::UserGuest.create!
    category = quality_categories(:tone)
    qualities = 5.times.map { |index| category.qualities.create!(name: "Match quality #{index}") }
    candidate = Registry::Film.create!(title: "Matching film")
    qualities.each { |quality| Registry::FilmQuality.create!(film: candidate, quality:) }
    ratings = 8.times.map do |index|
      film = Registry::Film.create!(title: "Source film #{index}")
      qualities.each { |quality| Registry::FilmQuality.create!(film:, quality:) }
      rating = Ratings::RatingFilm.create!(user:, film:).submit_rating!(value: "brilliant")
      Ratings::QualityScoring::ScoreRatingQualities.call(rating_id: rating.id)
      Recommendations::RecommendationFilm.new(user:, film:).suppress!
      rating
    end

    result = Recommendations::CandidateSelection::NextRecommendation.call(user_id: user.id)
    assert_equal candidate, result.recommendation_film.film
    assert_equal 65, result.match_percentage

    ratings.first(5).each_with_index do |rating, index|
      revised = rating.rating_film.revise_rating!(previous_rating_id: rating.id, value: "garbage")
      Ratings::QualityScoring::ScoreRatingQualities.call(rating_id: revised.id)
      expected_match = [ 63, 59, 55, 50, 45 ].fetch(index)
      queued = Recommendations::CandidateSelection::NextRecommendation.call(user_id: user.id)
      assert_equal result.recommendation_film, queued.recommendation_film
      assert_equal expected_match, queued.match_percentage
    end
  end
end
