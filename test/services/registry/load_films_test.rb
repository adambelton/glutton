require "test_helper"
require_relative "../../support/film_loading_sources"

class Registry::LoadFilmsTest < ActiveSupport::TestCase
  include FilmLoadingSources
  self.use_transactional_tests = false
  TMDB_IDS = (8_910_001..8_910_010).freeze

  setup do
    @quality = assessment_quality(name: "Batch loading quality")
    @sources = loading_sources
  end

  teardown do
    # Delete only disposable batch fixtures; do not simulate model mutations.
    film_ids = Registry::Film.where(tmdb_id: TMDB_IDS).ids
    Registry::FilmQuality.where(film_id: film_ids).delete_all
    Registry::FilmQualityEval.where(film_id: film_ids).delete_all
    Registry::Film.where(id: film_ids).delete_all
    Registry::Quality.where(id: @quality.id).delete_all
  end

  def load_films(**options)
    Registry::LoadFilms.call(**{ tmdb_ids: [ TMDB_IDS.first ], maximum_films: 10,
      maximum_requests_per_film: 2, maximum_cost_usd_per_film: 0.02, maximum_cost_usd: 0.20,
      film_loader: @sources }.merge(options))
  end

  test "a mixed batch retains successful stages and isolates every failed or zero-coverage film" do
    first, import_failure, assessment_failure, zero, unexpected, last = TMDB_IDS.first(6)
    sources = loading_sources(import_failure_ids: [ import_failure ], assessment_failure_ids: [ assessment_failure ],
      zero_ids: [ zero ], unexpected_ids: [ unexpected ])
    output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output)
    result = nil
    assert_no_difference [ "Library::LibraryFilm.count", "Rating.count", "DomainEvent.count" ] do
      assert_difference [ "Registry::Film.count", "Registry::FilmQualityEval.count" ], 5 do
        result = load_films(tmdb_ids: [ first, import_failure, assessment_failure, zero, first, unexpected, last ], film_loader: sources)
      end
    end
    assert_equal [ first, last ], Registry::Film.where(id: result.fetch(:loaded_film_ids)).order(:tmdb_id).pluck(:tmdb_id)
    warnings = result.fetch(:warnings)
    assert_equal [ :import_failed, :assessment_failed, :no_qualities, :import_failed, :unexpected_failure ], warnings.map { |warning| warning.fetch(:reason) }
    assert_equal :existing_film, warnings[3].fetch(:failure_reason)
    assert_nil warnings.first.fetch(:film_id)
    assert_equal Registry::Film.find_by!(tmdb_id: assessment_failure).id, warnings[1].fetch(:film_id)
    assert_not Registry::Film.exists?(tmdb_id: import_failure)
    [ assessment_failure, zero, unexpected ].each do |tmdb_id|
      film = Registry::Film.find_by!(tmdb_id:)
      assert film.has_source_context?
      assert_not film.has_film_qualities?
      assert_equal 1, film.film_quality_evals.count
    end
    assert_equal "completed", Registry::Film.find_by!(tmdb_id: zero).film_quality_evals.sole.output.fetch("status")
    assert_equal "failed", Registry::Film.find_by!(tmdb_id: unexpected).film_quality_evals.sole.output.fetch("status")
    assert_equal 14, result.fetch(:limits).fetch(:maximum_requests)
    assert_equal BigDecimal("0.14"), result.fetch(:limits).fetch(:maximum_cost_usd)
    refute_includes output.string, "private-loading-test-key"
    refute_includes output.string, "private-provider-body"
    refute_match(/translation missing/i, output.string)
  ensure
    Rails.logger = original_logger
  end

  test "the whole ID list is validated before loading the first film" do
    [ nil, "8910001", [], [ TMDB_IDS.first, "8910002" ], [ 0 ], [ -1 ], [ 1.5 ], [ true ] ].each do |tmdb_ids|
      error = assert_raises(Registry::InvalidFilmLoad) { load_films(tmdb_ids:) }
      assert_equal :invalid_tmdb_ids, error.reason
    end
    assert_empty @sources.source_requests
    assert_empty @sources.assessment_requests
  end

  test "film count request and cost limits are rejected before acquisition" do
    [ 0, -1, "2", 1.5, nil ].each do |maximum_films|
      assert_raises(Registry::InvalidFilmLoad) { load_films(maximum_films:) }
    end
    assert_raises(Registry::InvalidFilmLoad) { load_films(tmdb_ids: TMDB_IDS.first(2), maximum_films: 1) }
    [ 0, -1, "2", 1.5, nil ].each do |maximum_requests_per_film|
      assert_raises(Registry::InvalidFilmLoad) { load_films(maximum_requests_per_film:) }
    end
    [ 0, -1, "0.02", Float::NAN, Float::INFINITY, Complex(1, 2), Rational(1, 2), nil ].each do |cost|
      assert_raises(Registry::InvalidFilmLoad) { load_films(maximum_cost_usd_per_film: cost) }
      assert_raises(Registry::InvalidFilmLoad) { load_films(maximum_cost_usd: cost) }
    end
    assert_empty @sources.source_requests
  end

  test "the total worst-case allocation is checked before importing any film" do
    error = assert_raises(Registry::InvalidFilmLoad) do
      load_films(tmdb_ids: TMDB_IDS.first(2), maximum_cost_usd_per_film: 0.02, maximum_cost_usd: 0.03)
    end
    assert_equal :batch_budget_exceeded, error.reason
    assert_empty @sources.source_requests
    assert_empty @sources.assessment_requests
    assert_not Registry::Film.where(tmdb_id: TMDB_IDS).exists?
  end

  test "decimal allocations do not reject a fitting budget through float rounding" do
    result = load_films(tmdb_ids: TMDB_IDS.first(3), maximum_cost_usd_per_film: 0.1, maximum_cost_usd: 0.3)
    assert_equal 3, result.fetch(:loaded_film_ids).size
    assert_equal BigDecimal("0.3"), result.fetch(:limits).fetch(:maximum_cost_usd)
    assert_empty result.fetch(:warnings)
  end

  test "mutating the caller list cannot expand the validated batch" do
    ids = TMDB_IDS.first(2)
    sources = @sources
    loader = lambda do |tmdb_id:, maximum_requests:, maximum_cost_usd:|
      ids << TMDB_IDS.first + 2 if tmdb_id == TMDB_IDS.first
      sources.call(tmdb_id:, maximum_requests:, maximum_cost_usd:)
    end
    result = load_films(tmdb_ids: ids, maximum_films: 2, maximum_cost_usd: 0.04, film_loader: loader)
    assert_equal 3, ids.size
    assert_equal 2, result.fetch(:limits).fetch(:films)
    assert_equal 2, result.fetch(:loaded_film_ids).size
    assert_not Registry::Film.exists?(tmdb_id: TMDB_IDS.first + 2)
  end

  test "caller transactions are rejected instead of wrapping provider work" do
    Registry::Film.transaction do
      error = assert_raises(Registry::InvalidFilmLoad) { load_films }
      assert_equal :open_transaction, error.reason
    end
    assert_empty @sources.source_requests
  end

  test "a request limit failure for one film does not consume another film's allocation" do
    result = load_films(tmdb_ids: TMDB_IDS.first(2), maximum_requests_per_film: 1)
    assert_empty result.fetch(:loaded_film_ids)
    assert_equal [ :request_limit, :request_limit ], result.fetch(:warnings).map { |warning| warning.fetch(:failure_reason) }
    assert_equal TMDB_IDS.first(2), @sources.assessment_requests.map { |request| request.fetch(:tmdb_id) }
    assert_equal 2, Registry::Film.where(tmdb_id: TMDB_IDS.first(2)).count
  end

  test "unused batch budget cannot be borrowed past a per-film spend limit" do
    result = load_films(tmdb_ids: TMDB_IDS.first(2), maximum_cost_usd_per_film: 0.00000001, maximum_cost_usd: 0.04)
    assert_empty result.fetch(:loaded_film_ids)
    assert_equal [ :budget_exceeded, :budget_exceeded ], result.fetch(:warnings).map { |warning| warning.fetch(:failure_reason) }
    assert_empty @sources.assessment_requests
    assert_equal BigDecimal("0.00000002"), result.fetch(:limits).fetch(:maximum_cost_usd)
  end
end
