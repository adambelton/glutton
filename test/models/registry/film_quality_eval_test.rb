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
    assert_equal "pending", evaluation.application.fetch("status")
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
    evaluation.apply_initial_qualities!
    assert_equal evaluation, @film.film_qualities.sole.film_quality_eval
    link = @film.film_qualities.sole.reload
    assert_equal [ "P1" ], link.film_quality_eval.output.fetch("evidence").fetch(link.quality_id.to_s)
    assert_equal "applied", evaluation.reload.application.fetch("status")
    assert_equal @film.film_qualities.ids, evaluation.application.fetch("film_quality_ids")
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
    [ {}, { "status" => nil }, { "status" => "unknown" } ].each do |application|
      assert_raises(ActiveRecord::StatementInvalid) do
        Registry::FilmQualityEval.transaction(requires_new: true) do
          Registry::FilmQualityEval.insert_all!([ { film_id: @film.id, output: evaluation.output, application: } ])
        end
      end
    end
  end

  test "an application outcome is recorded once without changing the evaluation output" do
    evaluation = record_evaluation
    original_output = evaluation.output.deep_dup
    evaluation.record_application_failure!(reason: :stale_inputs)
    assert_equal "failed", evaluation.reload.application.fetch("status")
    assert_equal "stale_inputs", evaluation.application.fetch("reason")
    assert_equal original_output, evaluation.output
    assert_raises(ActiveRecord::ReadOnlyRecord) { evaluation.apply_initial_qualities! }
    assert_equal "failed", evaluation.reload.application.fetch("status")
  end

  test "a removed selected quality prevents application instead of silently omitting it" do
    evaluation = record_evaluation
    @quality.destroy!
    error = assert_raises(Registry::AssignmentFailed) do
      evaluation.apply_initial_qualities!
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
