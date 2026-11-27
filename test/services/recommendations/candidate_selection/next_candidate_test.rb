require "test_helper"

class Recommendations::NextCandidateTest < ActiveSupport::TestCase
  setup do
    @user = Identity::UserGuest.create!
    category = quality_categories(:tone)
    @positive = category.qualities.create!(name: "Slow pace")
    @negative = category.qualities.create!(name: "Rapid cuts")
  end

  def next_candidate(**options)
    Recommendations::CandidateSelection::NextCandidate.call(user: @user, **options)
  end

  def film(title, *qualities)
    Registry::Film.create!(title:).tap do |film|
      qualities.each { |quality| Registry::FilmQuality.create!(film:, quality:) }
    end
  end

  def assess(quality:, value:, user: @user)
    evidence = film("Evidence for #{quality.name}", quality)
    rating_film = Ratings::RatingFilm.create!(user:, film: evidence)
    rating = rating_film.submit_rating!(value:)
    rating.apply_quality_evaluation!(evaluation: record_evaluation(rating:, quality:))
    Recommendations::RecommendationFilm.new(user:, film: evidence).suppress!
    rating
  end

  def record_evaluation(rating:, quality:)
    Ratings::RatingQualityEval.create!(rating:, input: [], output: {
      notes: {}, qualities: { quality.id.to_s => { name: quality.name, match_rule: nil, not_sufficient: nil } },
      calls: [], decisions: [ { quality_id: quality.id, determination: nil, supporting_rating_ids: [], result_ids: [] } ]
    })
  end

  test "ranking uses signed current scores and filters the one-time exclusion before choosing" do
    3.times { assess(quality: @positive, value: "brilliant") }
    2.times { assess(quality: @negative, value: "garbage") }
    better = film("Positive match", @positive)
    mixed = film("Mixed match", @positive, @negative)
    second_mixed = film("Equal mixed match", @positive, @negative)
    worse = film("Negative match", @negative)

    assert_equal better.id, next_candidate.candidate.film_id
    result = next_candidate(excluding_film_id: better.id)
    assert result.unlocked?
    assert_equal mixed.id, result.candidate.film_id
    assert_operator result.candidate.contributions.fetch(@positive.id), :>, 0
    assert_operator result.candidate.contributions.fetch(@negative.id), :<, 0
    [ better, mixed, second_mixed ].each { |film| Recommendations::RecommendationFilm.new(user: @user, film:).suppress! }
    result = next_candidate
    assert_equal worse.id, result.candidate.film_id
    assert_operator result.candidate.score, :<, 0
  end

  test "exact signed totals combine all classifications from the newest applied set" do
    implicit_quality = quality_categories(:tone).qualities.create!(name: "Quiet scenes")
    evidence = film("Mixed evidence", @positive, implicit_quality, @negative)
    rating_film = Ratings::RatingFilm.create!(user: @user, film: evidence)
    rating = rating_film.submit_rating!(value: "brilliant", notes: "I loved the slow pace.")
    Recommendations::RecommendationFilm.new(user: @user, film: evidence).suppress!

    qualities = [ @positive, implicit_quality, @negative ]
    client = Object.new
    client.define_singleton_method(:configuration) { { "model" => "fixture" } }
    accepted = [ "notes_#{rating.id}_quality_#{@positive.id}_reinforces", "quality_#{implicit_quality.id}_reinforces" ]
    client.define_singleton_method(:answer) do |questions:, **|
      { "model" => "fixture", "usage" => { "input_tokens" => 0, "output_tokens" => 0 },
        "answers" => questions.keys.index_with { |id| { "type" => "noul", "noul" => (accepted.include?(id) ? 0.95 : 0.05) } } }
    end
    first = Ratings::QualityScoring::ScoreRatingQualities.call(rating_id: rating.id, client:, tracer_provider: nil)
    assert_equal 3, first.rating_qualities.size

    profile = Ratings::TasteProfile.create!(user: @user)
    profile_evaluation = Ratings::TasteProfileRevisionEval.create!(taste_profile: profile, input: [], output: {
      evidence: [ { rating_id: rating.id, film_id: evidence.id, film_title: evidence.title, film_release_date: nil, text: rating.notes } ],
      profile: "Enjoys quiet scenes.",
      synthesis: { provider: "fixture", model: "fixture", usage: { input: 0, output: 0 } },
      trace_id: nil
    })
    revision = profile.publish_revision!(evaluation: profile_evaluation)
    newest = Ratings::QualityScoring::ScoreRatingQualities.call(rating_id: rating.id, client:, tracer_provider: nil)
    assert_equal revision.id, newest.profile_revision_id
    Ratings::RatingQualityEval.create!(rating:, input: [], output: first.output)

    4.times { assess(quality: @negative, value: "garbage") }
    expected = film("All qualities", *qualities)
    result = next_candidate
    assert_equal expected, result.film
    assert_equal 5, result.assessed_film_count
    assert_equal({ @positive.id => 5, implicit_quality.id => 3, @negative.id => -6 }, result.candidate.contributions)
    assert_equal 2, result.candidate.score
  end

  test "a pending revision drops the old scores from the threshold and unapplied evaluations do not unlock" do
    ratings = 5.times.map { assess(quality: @positive, value: "brilliant") }
    assert next_candidate.unlocked?
    current = ratings.first
    revised = current.rating_film.revise_rating!(previous_rating_id: current.id, value: "garbage")
    record_evaluation(rating: revised, quality: @positive)
    assess(quality: @positive, value: "brilliant", user: Identity::UserGuest.create!)
    result = next_candidate
    assert_equal 4, result.assessed_film_count
    assert_nil result.candidate
    assert_not result.unlocked?
  end

  test "a recorded but unapplied newer evaluation cannot hide applied evidence" do
    ratings = 5.times.map { assess(quality: @positive, value: "brilliant") }
    record_evaluation(rating: ratings.first, quality: @positive)
    best = film("Best match", @positive)
    response = Recommendations::RecordFilmResponse.call(user_id: @user.id, film_id: best.id, response: "rejected")
    neutral = film("Neutral match")

    result = next_candidate
    assert_equal 5, result.assessed_film_count
    assert_equal neutral.id, result.candidate.film_id
    assert_equal "rejected", response.reload.response
    assert_nil next_candidate(excluding_film_id: neutral.id).candidate
  end
end
