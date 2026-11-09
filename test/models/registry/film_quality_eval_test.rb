require "test_helper"
require_relative "../../support/quality_assessment_sources"

class Registry::FilmQualityEvalTest < ActiveSupport::TestCase
  include QualityAssessmentSources

  setup do
    @film = imported_assignment_film
    @quality = assessment_quality
  end

  def record_evaluation
    assessment = Registry::InitialQualityAssessment.new(source: film_source_snapshot(film: @film),
      definitions: quality_definition_snapshots,
      categories: quality_category_snapshots).call(client: Client.new)
    Registry::FilmQualityEval.record!(film: @film, assessment:)
  end

  test "recording is separate from application and retained evidence survives vocabulary edits" do
    evaluation = record_evaluation
    assert_empty @film.reload.film_qualities
    original_category_id = @quality.quality_category_id
    @quality.recategorise!(quality_category: quality_categories(:emotional_character))
    assert_equal original_category_id, evaluation.reload.output.fetch("definitions").sole.fetch("quality_category_id")
    assert_raises(ActiveRecord::DeleteRestrictionError) { @film.destroy! }
    assert_raises(ActiveRecord::ReadOnlyRecord) { evaluation.touch }
    assert_raises(ActiveRecord::ReadOnlyRecord) { evaluation.destroy! }
  end

  test "accepted links must match the evaluation film and selected quality" do
    evaluation = record_evaluation
    other_film = imported_assignment_film(tmdb_id: 800002)
    other_quality = assessment_quality(name: "Other quality")
    [ { film: other_film, quality: @quality },
      { film: @film, quality: other_quality } ].each do |attributes|
      link = Registry::FilmQuality.new(**attributes, film_quality_eval: evaluation)
      assert_not link.valid?
      assert link.errors.of_kind?(:film_quality_eval, :invalid)
    end
    @film.apply_initial_qualities!(evaluation:)
    assert_equal evaluation, @film.film_qualities.sole.film_quality_eval
    link = @film.film_qualities.sole.reload
    assert_empty link.film_quality_eval.output.fetch("evidence")
    assert_equal [ link.id ], evaluation.film_qualities.ids
    assert_raises(ActiveRecord::DeleteRestrictionError) { @film.destroy! }
  end

  test "storage prevents dangling and cross-film evaluation links and incomplete evaluation records" do
    evaluation = record_evaluation
    other_film = imported_assignment_film(tmdb_id: 800002)
    [ { film_id: other_film.id, film_quality_eval_id: evaluation.id },
      { film_id: @film.id, film_quality_eval_id: -1 } ].each do |identities|
      assert_raises(ActiveRecord::InvalidForeignKey) do
        Registry::FilmQuality.transaction(requires_new: true) do
          # Deliberate bypass verifies the same-film provenance storage contract.
          Registry::FilmQuality.insert_all!([ identities.merge(quality_id: @quality.id) ])
        end
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Registry::FilmQualityEval.transaction(requires_new: true) do
        Registry::FilmQualityEval.insert_all!([ { film_id: @film.id, output: {} } ])
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Registry::FilmQualityEval.transaction(requires_new: true) do
        Registry::FilmQualityEval.insert_all!([ { film_id: @film.id, input: {}, output: evaluation.output } ])
      end
    end
  end

  test "rejects malformed snapshot contents even when all required fields are present" do
    snapshot = record_evaluation.output

    assert_no_difference "Registry::FilmQualityEval.count" do
      malformed_fields = [
        { "selected_quality_ids" => [ @quality.id.to_s ] },
        { "calls" => [ nil ] },
        { "source" => [] },
        { "support" => { @quality.id.to_s => "0.95" } },
        { "evidence" => { @quality.id.to_s => "P1" } }
      ]
      malformed_fields.each do |invalid_fields|
        assert_raises(ActiveRecord::RecordInvalid) do
          Registry::FilmQualityEval.create!(film: @film, output: snapshot.merge(invalid_fields))
        end
      end
    end
  end

  test "a removed selected quality prevents application instead of silently omitting it" do
    evaluation = record_evaluation
    @quality.destroy!
    error = assert_raises(Registry::AssignmentFailed) do
      @film.apply_initial_qualities!(evaluation:)
    end
    assert_equal :stale_inputs, error.reason
    assert_empty @film.reload.film_qualities
  end

  test "an uncompleted assessment cannot be recorded as a completed evaluation" do
    assessment = Registry::InitialQualityAssessment.new(source: film_source_snapshot(film: @film),
      definitions: [], categories: [])
    assert_raises(ActiveRecord::RecordInvalid) { Registry::FilmQualityEval.record!(film: @film, assessment:) }
    assert_empty @film.film_quality_evals
  end
end
