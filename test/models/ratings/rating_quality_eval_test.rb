require "test_helper"

class Ratings::RatingQualityEvalTest < ActiveSupport::TestCase
  setup do
    film = Registry::Film.create!(title: "Assessed film")
    category = quality_categories(:tone)
    @quality = category.qualities.create!(name: "Dread", match_rule: "Sustained anticipation", not_sufficient: "A single jump scare")
    @other_quality = category.qualities.create!(name: "Isolation")
    [ @quality, @other_quality ].each { |quality| Registry::FilmQuality.create!(film:, quality:) }
    @rating_film = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film:)
    @rating = @rating_film.submit_rating!(value: Ratings::Rating::Values::BRILLIANT, notes: "The dread builds slowly.")
  end

  test "recording preserves evidence and Rating applies a complete score set" do
    snapshot = assessment_output
    evaluation = record(snapshot)

    assert_equal snapshot.deep_stringify_keys, evaluation.reload.output.slice(*snapshot.keys.map(&:to_s))
    assert_empty scores(evaluation)
    assert @rating.apply_quality_evaluation!(evaluation:)
    assert_equal({ @quality.id => 5, @other_quality.id => 2 }, scores(evaluation))
    assert_equal [ [ "explicitly_expressed", 5 ], [ "unexpressed", 2 ] ],
      evaluation.rating_qualities.order(:quality_id).pluck(:classification, :score)
    assert_equal "The dread builds slowly.", @rating.notes
    assert_raises(ActiveRecord::ReadOnlyRecord) { evaluation.save! }
  end

  test "rejects supporting expressions from another rating and references to uncaptured qualities or results" do
    other_film = Registry::Film.create!(title: "Another film")
    other_rating_film = Ratings::RatingFilm.create!(user: @rating_film.user, film: other_film)
    other_rating = other_rating_film.submit_rating!(value: Ratings::Rating::Values::PRETTY_GOOD,
      notes: "Different thought.")
    invalid_evidence = [
      assessment_output(rating_id: other_rating.id),
      assessment_output(quality_id: -1),
      assessment_output(result_id: "missing")
    ]

    assert_no_difference "Ratings::RatingQualityEval.count" do
      invalid_evidence.each do |snapshot|
        assert_raises(ActiveRecord::RecordInvalid) do
          record(snapshot)
        end
      end
    end
  end

  test "Rating skips the same profile and rejects a superseded rating" do
    evaluation = record(assessment_output)
    assert @rating.apply_quality_evaluation!(evaluation:)
    assert_no_difference "Ratings::RatingQuality.count" do
      assert_nil @rating.apply_quality_evaluation!(evaluation:)
    end

    revision = @rating_film.revise_rating!(previous_rating_id: @rating.id, value: Ratings::Rating::Values::PRETTY_GOOD)
    error = assert_raises(Ratings::Errors::QualityAssessmentFailed) { @rating.apply_quality_evaluation!(evaluation:) }
    assert_equal :stale_rating, error.reason
    assert_empty revision.rating_quality_evals
  end

  test "malformed question and result pairs fail at recording and direct creation" do
    snapshot = assessment_output.merge(calls: [ [ { id: "q1", question: "Does the expression address dread?" } ] ])

    assert_no_difference "Ratings::RatingQualityEval.count" do
      assert_raises(ActiveRecord::RecordInvalid) { record(snapshot) }
      assert_raises(ActiveRecord::RecordInvalid) { Ratings::RatingQualityEval.create!(rating: @rating, output: snapshot) }
    end
  end

  test "database rejects output without the required snapshot fields" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Ratings::RatingQualityEval.transaction(requires_new: true) do
        Ratings::RatingQualityEval.insert_all!([ { rating_id: @rating.id, output: {} } ])
      end
    end
  end

  test "conflicting decisions cannot create scores" do
    snapshot = assessment_output
    snapshot[:decisions] << snapshot[:decisions].first.dup
    evaluation = record(snapshot)

    assert_no_difference "Ratings::RatingQuality.count" do
      assert_raises(Ratings::Errors::QualityApplicationUnavailable) { @rating.apply_quality_evaluation!(evaluation:) }
    end
  end

  test "Rating scores the captured qualities after Registry accepts another quality" do
    evaluation = record(assessment_output)
    quality = quality_categories(:tone).qualities.create!(name: "Unease")
    Registry::FilmQuality.create!(film: @rating_film.film, quality:)

    assert @rating.apply_quality_evaluation!(evaluation:)
    assert_equal({ @quality.id => 5, @other_quality.id => 2 }, scores(evaluation))
  end

  private

  def scores(evaluation)
    evaluation.rating_qualities.pluck(:quality_id, :score).to_h
  end

  def record(snapshot)
    assessment = Struct.new(:result, :input).new(snapshot, [])
    Ratings::RatingQualityEval.record!(rating: @rating, assessment:)
  end

  def assessment_output(rating_id: @rating.id, quality_id: @quality.id, result_id: "q1")
    {
      notes: { @rating.id.to_s => @rating.notes },
      qualities: {
        @quality.id.to_s => { name: @quality.name, match_rule: @quality.match_rule, not_sufficient: @quality.not_sufficient },
        @other_quality.id.to_s => { name: @other_quality.name, match_rule: nil, not_sufficient: nil }
      },
      calls: [ [
        { id: "q1", question: "Does the expression address dread?", result: { probability: 0.95 } },
        { id: "q2", question: "Does the expression address isolation?", result: { probability: 0.05 } }
      ] ],
      decisions: [
        { quality_id:, applicable: true, supporting_rating_ids: [ rating_id ], result_ids: [ result_id ] },
        { quality_id: @other_quality.id, applicable: false, supporting_rating_ids: [], result_ids: [ "q2" ] }
      ]
    }
  end
end
