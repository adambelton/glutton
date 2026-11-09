require "test_helper"

class Ratings::RatingQualityEvalTest < ActiveSupport::TestCase
  setup do
    film = Registry::Film.create!(title: "Assessed film")
    category = quality_categories(:tone)
    @quality = category.qualities.create!(name: "Dread", match_rule: "Sustained anticipation", not_sufficient: "A single jump scare")
    @other_quality = category.qualities.create!(name: "Isolation")
    [ @quality, @other_quality ].each { |quality| Registry::FilmQuality.create!(film:, quality:) }
    @rating_film = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film:)
    @rating = @rating_film.submit_rating!(value: Ratings::Rating::Values::BRILLIANT, expression_texts: [ "The dread builds slowly." ])
    @expression = @rating.rating_expressions.sole
  end

  test "completed evidence preserves ordered results and supporting inputs without changing baseline scores" do
    snapshot = assessment_output
    baseline = @rating.rating_qualities.order(:quality_id).pluck(:quality_id, :score, :classification)
    evaluation = record(snapshot)

    assert_equal snapshot.deep_stringify_keys, evaluation.reload.output.slice(*snapshot.keys.map(&:to_s))
    assert_equal baseline, @rating.rating_qualities.order(:quality_id).pluck(:quality_id, :score, :classification)
    assert_equal @expression.text, @rating.rating_expressions.sole.text
    assert_raises(ActiveRecord::ReadOnlyRecord) { evaluation.save! }
  end

  test "rejects supporting expressions from another rating and references to uncaptured qualities or results" do
    revision = @rating_film.revise_rating!(previous_rating_id: @rating.id, value: Ratings::Rating::Values::PRETTY_GOOD,
      expression_texts: [ "Different thought." ])
    invalid_evidence = [
      assessment_output(expression_id: revision.rating_expressions.sole.id),
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

  test "separate assessments preserve identical evidence and survive revision" do
    first = record(assessment_output)
    second = record(assessment_output)
    revision = @rating_film.revise_rating!(previous_rating_id: @rating.id, value: Ratings::Rating::Values::PRETTY_GOOD)

    assert_equal [ first.id, second.id ], @rating.rating_quality_evals.order(:id).ids
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

  test "application creates scores once for the same profile revision" do
    first = record(assessment_output)
    assert_empty @rating.rating_qualities
    first_scores = first.apply_quality_scores!
    assert_equal [ [ "explicitly_expressed", 5 ], [ "unexpressed", 2 ] ],
      first.rating_qualities.order(:quality_id).pluck(:classification, :score)
    assert_equal({ @quality.id => 5, @other_quality.id => 2 }, scores(first))
    assert_equal [ @expression.id ], first_scores.first.rating_quality_eval.output.fetch("decisions").first.fetch("supporting_expression_ids")

    second = record(assessment_output)
    assert_no_difference "Ratings::RatingQuality.count" do
      assert_raises(Ratings::QualityApplicationUnavailable) { second.apply_quality_scores! }
      assert_raises(Ratings::QualityApplicationUnavailable) { first.apply_quality_scores! }
    end
    assert_empty second.rating_qualities
    assert_equal({ @quality.id => 5, @other_quality.id => 2 }, scores(first))
  end

  test "conflicting evaluations leave the previously applied scores intact" do
    snapshot = assessment_output
    snapshot[:decisions] << snapshot[:decisions].first.dup
    conflicting = record(snapshot)

    assert_no_difference "Ratings::RatingQuality.count" do
      assert_raises(Ratings::QualityApplicationUnavailable) { conflicting.apply_quality_scores! }
    end
    applied = record(assessment_output)
    applied.apply_quality_scores!
    assert_equal 5, scores(applied).fetch(@quality.id)

    revision = @rating_film.revise_rating!(previous_rating_id: @rating.id, value: Ratings::Rating::Values::NOT_FOR_ME,
      expression_texts: [ "The dread put me off." ])
    assert_empty revision.rating_qualities

    @rating = revision
    @expression = revision.rating_expressions.sole
    revision_evaluation = record(assessment_output)
    revision_evaluation.apply_quality_scores!
    assert_equal({ @quality.id => -3, @other_quality.id => -1 }, scores(revision_evaluation))
  end

  test "application scores the captured qualities after Registry accepts another quality" do
    evaluation = record(assessment_output)
    quality = quality_categories(:tone).qualities.create!(name: "Unease")
    Registry::FilmQuality.create!(film: @rating_film.film, quality:)

    evaluation.apply_quality_scores!

    assert_equal({ @quality.id => 5, @other_quality.id => 2 }, scores(evaluation))
  end

  test "application uses the product score weights captured in the evaluation" do
    evaluation = record(assessment_output)

    weights = evaluation.reload.output.fetch("score_weights")
    assert_equal 2, weights.dig("unexpressed", "brilliant")
    assert_equal({ "brilliant" => 4, "pretty_good" => 2, "not_for_me" => -2, "garbage" => -4 },
      weights.fetch("implicitly_expressed"))
    assert_equal 5, weights.dig("explicitly_expressed", "brilliant")
  end

  test "application honors score weights captured by older assessments" do
    snapshot = assessment_output.merge(question_policy: {
      scores: {
        explicitly_expressed: { brilliant: 7 },
        unexpressed: { brilliant: 1 }
      }
    })
    evaluation = Ratings::RatingQualityEval.create!(rating: @rating, output: snapshot)

    evaluation.apply_quality_scores!

    assert_equal({ @quality.id => 7, @other_quality.id => 1 }, scores(evaluation))
  end

  private

  def scores(evaluation)
    evaluation.rating_qualities.pluck(:quality_id, :score).to_h
  end

  def record(snapshot)
    assessment = Struct.new(:result).new(snapshot)
    Ratings::RatingQualityEval.record!(rating: @rating, assessment:)
  end

  def assessment_output(expression_id: @expression.id, quality_id: @quality.id, result_id: "q1")
    {
      expressions: { @expression.id.to_s => @expression.text },
      qualities: {
        @quality.id.to_s => { name: @quality.name, match_rule: @quality.match_rule, not_sufficient: @quality.not_sufficient },
        @other_quality.id.to_s => { name: @other_quality.name, match_rule: nil, not_sufficient: nil }
      },
      calls: [ [
        { id: "q1", question: "Does the expression address dread?", result: { probability: 0.95 } },
        { id: "q2", question: "Does the expression address isolation?", result: { probability: 0.05 } }
      ] ],
      decisions: [
        { quality_id:, applicable: true, supporting_expression_ids: [ expression_id ], result_ids: [ result_id ] },
        { quality_id: @other_quality.id, applicable: false, supporting_expression_ids: [], result_ids: [ "q2" ] }
      ]
    }
  end
end
