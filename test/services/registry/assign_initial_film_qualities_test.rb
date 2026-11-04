require "test_helper"
require_relative "../../support/quality_assessment_sources"

class Registry::AssignInitialFilmQualitiesTest < ActiveSupport::TestCase
  include QualityAssessmentSources

  test "assigns threshold matches in category order with source evidence and an inspectable result" do
    film = imported_assignment_film
    first = assessment_quality(name: "First")
    second = assessment_quality(name: "Second")
    below = assessment_quality(name: "Below")
    client = Client.new(support: { "quality_#{first.id}" => 0.6, "quality_#{second.id}" => 0.8, "quality_#{below.id}" => 0.59 })
    result = nil
    assert_no_difference [ "Library::LibraryFilm.count", "Rating.count", "DomainEvent.count", "Registry::Quality.count" ] do
      result = Registry::AssignInitialFilmQualities.call(film_id: film.id, client:)
      assert_equal film, result.fetch(:film)
    end
    assert_equal [ first.id, second.id ].sort, film.reload.quality_ids.sort
    assert_equal({ first.id.to_s => [ "P1" ], second.id.to_s => [ "P1" ] }, result.fetch(:film_quality_eval).reload.output.fetch("evidence"))
    assessment_result = result.fetch(:film_quality_eval).output
    assert_equal [ second.id, first.id ], assessment_result.fetch("selected_quality_ids")
    assert_equal 0.59, assessment_result.fetch("support").fetch(below.id.to_s)
    assert_equal film.wikipedia_context, assessment_result.dig("source", "wikipedia_context")
    assert_equal "jev-1.14.0", assessment_result.fetch("model")
    evaluation = result.fetch(:film_quality_eval).reload
    assert_equal assessment_result, evaluation.output
    assert_equal film, evaluation.film
    assert_equal [ evaluation.id ], film.film_qualities.distinct.pluck(:film_quality_eval_id)
    assert_equal client.requests.map { |request| request.fetch(:questions).deep_stringify_keys }, evaluation.output.fetch("calls").map { |call| call.dig("request", "questions") }
    assert_equal 2, evaluation.output.fetch("call_count")
    assert_equal client.requests.map { |request| request.fetch(:state).deep_stringify_keys }, evaluation.output.fetch("calls").map { |call| call.dig("request", "state") }
    assert_equal 2, evaluation.output.fetch("calls").count { |call| call.fetch("status") == "completed" }
    assert_equal "applied", evaluation.application.fetch("status")
    assert_equal film.film_qualities.order(:id).ids, evaluation.application.fetch("film_quality_ids").sort
    assert_equal [ "selected", "selected", "below_threshold" ], evaluation.output.fetch("selection_decisions").sort_by { |decision| decision.fetch("quality_id") }.map { |decision| decision.fetch("reason") }
    assert_equal 200, assessment_result.fetch("input_tokens")
    assert_equal [ "quality-support", "quality-evidence" ], client.requests.map { |request| request.fetch(:phase) }
    assert_not client.requests.first.fetch(:state).key?("categories")
    assert_equal "Do the supplied source_paragraphs support First in this film?", client.requests.first.dig(:questions, "quality_#{first.id}", "instructions")
    timestamp = film.updated_at
    error = assert_raises(Registry::AssignmentFailed) do
      Registry::AssignInitialFilmQualities.call(film_id: film.id, client: Object.new)
    end
    assert_equal :already_assigned, error.reason
    assert_equal timestamp, film.reload.updated_at
  end

  test "zero matches create no associations and an explicit later request assesses again" do
    film = imported_assignment_film
    assessment_quality
    client = Client.new(default_support: 0.1)
    result = Registry::AssignInitialFilmQualities.call(film_id: film.id, client:)
    assert_empty film.reload.film_qualities
    assert_equal [], result.fetch(:film_quality_eval).output.fetch("selected_quality_ids")
    assert_equal 1, client.requests.size
    second = Registry::AssignInitialFilmQualities.call(film_id: film.id, client:)
    assert_empty second.fetch(:film_qualities)
    assert_equal 2, client.requests.size
    assert_equal 2, film.film_quality_evals.count
    assert_not_equal result.fetch(:film_quality_eval).id, second.fetch(:film_quality_eval).id
  end

  test "missing unready empty vocabulary and incomplete definitions fail before provider calls" do
    unready = Registry::Film.create!(title: "No source")
    error = assert_raises(Registry::AssignmentFailed) { Registry::AssignInitialFilmQualities.call(film_id: unready.id, client: Object.new) }
    assert_equal :unready_film, error.reason
    film = imported_assignment_film
    error = assert_raises(Registry::AssignmentFailed) { Registry::AssignInitialFilmQualities.call(film_id: film.id, client: Object.new) }
    assert_equal :invalid_vocabulary, error.reason
    Registry::Quality.create!(name: "Missing definition", quality_category: quality_categories(:tone))
    error = assert_raises(Registry::AssignmentFailed) { Registry::AssignInitialFilmQualities.call(film_id: film.id, client: Object.new) }
    assert_equal :invalid_vocabulary, error.reason
    film.destroy!
    error = assert_raises(Registry::AssignmentFailed) { Registry::AssignInitialFilmQualities.call(film_id: film.id, client: Object.new) }
    assert_equal :film_missing, error.reason
  end

  test "preexisting manual associations are not replaced" do
    film = imported_assignment_film
    quality = assessment_quality
    link = Registry::FilmQuality.create!(film:, quality:)
    error = assert_raises(Registry::AssignmentFailed) { Registry::AssignInitialFilmQualities.call(film_id: film.id, client: Object.new) }
    assert_equal :already_assigned, error.reason
    assert_equal link.id, film.reload.film_qualities.sole.id
  end

  test "a changed vocabulary during retrieval is rejected with no associations" do
    film = imported_assignment_film
    quality = assessment_quality
    other_category = quality_categories(:emotional_character)
    changed = false
    client = Client.new(before_answer: lambda do
      unless changed
        quality.recategorise!(quality_category: other_category)
        changed = true
      end
    end)
    error = assert_raises(Registry::AssignmentFailed) { Registry::AssignInitialFilmQualities.call(film_id: film.id, client:) }
    assert_equal :stale_inputs, error.reason
    assert_equal 1, film.film_quality_evals.count
    assert_equal "stale_inputs", film.film_quality_evals.sole.application.fetch("reason")
    assert_empty film.reload.film_qualities
  end

  test "an added quality during retrieval is rejected as changed membership" do
    film = imported_assignment_film
    assessment_quality
    added = false
    client = Client.new(before_answer: lambda do
      unless added
        assessment_quality(name: "New member")
        added = true
      end
    end)
    error = assert_raises(Registry::AssignmentFailed) { Registry::AssignInitialFilmQualities.call(film_id: film.id, client:) }
    assert_equal :stale_inputs, error.reason
  end

  test "an intervening manual association is an explicit failure" do
    film = imported_assignment_film
    quality = assessment_quality
    inserted = false
    client = Client.new(before_answer: lambda do
      unless inserted
        Registry::FilmQuality.create!(film:, quality:)
        inserted = true
      end
    end)
    error = assert_raises(Registry::AssignmentFailed) { Registry::AssignInitialFilmQualities.call(film_id: film.id, client:) }
    assert_equal :already_assigned, error.reason
    assert_equal 1, film.film_qualities.count
  end

  test "deletion during retrieval is explicit and never recreates the film" do
    film = imported_assignment_film
    assessment_quality
    removed = false
    client = Client.new(before_answer: lambda do
      unless removed
        film.destroy!
        removed = true
      end
    end)
    error = assert_raises(Registry::AssignmentFailed) { Registry::AssignInitialFilmQualities.call(film_id: film.id, client:) }
    assert_equal :film_missing, error.reason
    assert_not Registry::Film.exists?(id: film.id)
    assert_equal 0, Registry::FilmQuality.count
  end

  test "an evidence request failure cannot apply a partial assignment" do
    film = imported_assignment_film
    assessment_quality
    requests = 0
    client = Client.new(before_answer: lambda do
      requests += 1
      raise Registry::AssignmentFailed.new(reason: :timeout) if requests == 2
    end)
    error = assert_raises(Registry::AssignmentFailed) { Registry::AssignInitialFilmQualities.call(film_id: film.id, client:) }
    assert_equal :timeout, error.reason
    evaluation = film.film_quality_evals.sole
    assert_equal "failed", evaluation.output.fetch("status")
    assert_equal 2, evaluation.output.fetch("call_count")
    assert_equal [ "completed", "failed" ], evaluation.output.fetch("calls").map { |call| call.fetch("status") }
    assert_equal 0.7, evaluation.output.fetch("support").values.sole
    assert_equal "timeout", evaluation.application.fetch("reason")
    assert_equal [], evaluation.output.fetch("selected_quality_ids")
    assert_raises(Registry::AssignmentFailed) { evaluation.apply_initial_qualities! }
    assert_empty film.reload.film_qualities
  end

  test "model rejects a proposal based on a different source through its explicit action" do
    film = imported_assignment_film
    assessment_quality
    source = film_source_snapshot(film:).merge("title" => "Older title")
    assessment = Registry::InitialQualityAssessment.new(source:, definitions: quality_definition_snapshots,
      categories: quality_category_snapshots).call(client: Client.new)
    error = assert_raises(Registry::AssignmentFailed) { Registry::FilmQualityEval.record!(film:, assessment:).apply_initial_qualities! }
    assert_equal :stale_inputs, error.reason
    assert_empty film.reload.film_qualities
  end

  test "unexpected provider failure retains partial evidence without private exception text" do
    film = imported_assignment_film
    assessment_quality
    client = Client.new(before_answer: -> { raise "private-test-key private-provider-response" })
    assert_raises(RuntimeError) { Registry::AssignInitialFilmQualities.call(film_id: film.id, client:) }
    evaluation = film.film_quality_evals.sole
    assert_equal "failed", evaluation.output.fetch("status")
    assert_equal "unexpected_failure", evaluation.output.fetch("error").fetch("reason")
    assert_equal 1, evaluation.output.fetch("calls").size
    refute_includes evaluation.output.to_json, "private-test-key"
    refute_includes evaluation.output.to_json, "private-provider-response"
    assert_empty film.reload.film_qualities
  end

  test "category weights do not alter canonical membership" do
    film = imported_assignment_film
    zero = Registry::QualityCategory.create!(name: "Zero weight", weight: 0, maximum_qualities: 1)
    high = Registry::QualityCategory.create!(name: "High weight", weight: 100, maximum_qualities: 1)
    zero_quality = assessment_quality(category: zero, name: "Zero weighted quality")
    high_quality = assessment_quality(category: high, name: "High weighted quality")
    result = Registry::AssignInitialFilmQualities.call(film_id: film.id, client: Client.new(default_support: 0.6))
    assert_equal [ zero_quality.id, high_quality.id ].sort, film.reload.quality_ids.sort
    assert result.fetch(:film_quality_eval).output.fetch("categories").none? { |category| category.key?("weight") }
  end

  test "all application failure reasons have English translations" do
    I18n.t("registry.assignment.errors").each_key do |reason|
      refute_match(/translation missing/i, Registry::AssignmentFailed.new(reason:).message)
    end
  end

  test "failed association persistence rolls back every new association" do
    film = imported_assignment_film
    assessment_quality
    callback = -> { raise ActiveRecord::StatementInvalid, "injected association failure" }
    Registry::FilmQuality.set_callback(:create, :after, callback)
    assert_difference "Registry::FilmQualityEval.count", 1 do
      assert_no_difference "Registry::FilmQuality.count" do
        assert_raises(ActiveRecord::StatementInvalid) { Registry::AssignInitialFilmQualities.call(film_id: film.id, client: Client.new) }
      end
    end
    assert_equal "failed", film.film_quality_evals.sole.application.fetch("status")
    assert_equal "persistence_error", film.film_quality_evals.sole.application.fetch("reason")
  ensure
    Registry::FilmQuality.skip_callback(:create, :after, callback, raise: false)
  end
end
