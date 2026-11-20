require "test_helper"

class Recommendations::CalculateRecommendationMatchTest < ActiveSupport::TestCase
  test "rounding keeps a positive or negative total on its side of 50 percent" do
    quality_ids = (1..5).to_a
    rating_scores = (1..8).flat_map do |rating_id|
      quality_ids.map { |quality_id| [ rating_id, quality_id, rating_id.odd? ? 1 : -1 ] }
    end

    assert_equal 50, match(quality_ids, rating_scores)
    assert_equal 51, match(quality_ids, rating_scores + [ [ 9, 1, 1 ] ])
    assert_equal 49, match(quality_ids, rating_scores + [ [ 9, 1, -1 ] ])
  end

  test "a percentage needs support from enough assigned qualities and distinct ratings" do
    quality_ids = (1..5).to_a
    rating_scores = (1..8).flat_map do |rating_id|
      quality_ids.map { |quality_id| [ rating_id, quality_id, 2 ] }
    end

    assert_equal 65, match((1..8).to_a, rating_scores)
    assert_nil match((1..9).to_a, rating_scores)
    assert_nil match([], rating_scores)
    assert_nil match(quality_ids, rating_scores.reject { |rating_id, _, _| rating_id == 8 })
    assert_nil match(quality_ids, rating_scores.reject { |rating_id, quality_id, _| quality_id == 5 && rating_id > 2 })
  end

  private

  def match(quality_ids, rating_scores)
    Recommendations::CandidateSelection::CalculateRecommendationMatch.call(quality_ids:, rating_scores:)
  end
end
