require "test_helper"
require_relative "../../support/quality_assessment_sources"

class FilmKnowledge::AssignInitialFilmQualitiesJobTest < ActiveSupport::TestCase
  include QualityAssessmentSources

  test "warnings isolate zero coverage provider errors and unexpected failures from later films" do
    calls = []
    operation = lambda do |film_id:|
      calls << film_id
      case film_id
      when 1 then { film_qualities: [] }
      when 2 then raise FilmKnowledge::AssignmentFailed.new(reason: :timeout)
      when 3 then raise ActiveRecord::StatementInvalid, "private error body secret"
      when 4 then { film_qualities: [ FilmQuality.new ] }
      end
    end
    output = StringIO.new
    original_logger = Rails.logger
    original_operation = FilmKnowledge::AssignInitialFilmQualities.method(:call)
    Rails.logger = ActiveSupport::Logger.new(output)
    result = nil
    FilmKnowledge::AssignInitialFilmQualities.define_singleton_method(:call, operation)
    result = FilmKnowledge::AssignInitialFilmQualitiesJob.perform_now(film_ids: [ 1, 2, 3, 4 ])
    assert_equal [ 1, 2, 3, 4 ], calls
    assert_equal [ 4 ], result.fetch(:assigned_film_ids)
    assert_equal [ 1, 2, 3 ], result.fetch(:warnings).map { |warning| warning.fetch(:film_id) }
    assert_equal [ :no_qualities, :assessment_failed, :unexpected_failure ], result.fetch(:warnings).map { |warning| warning.fetch(:reason) }
    assert_includes result.fetch(:warnings).first.fetch(:message), "needs manual review"
    assert_includes result.fetch(:warnings)[1].fetch(:message), "timed out"
    refute_includes output.string, "private error body"
    refute_includes output.string, "secret"
    refute_match(/translation missing/i, output.string)
  ensure
    Rails.logger = original_logger
    FilmKnowledge::AssignInitialFilmQualities.define_singleton_method(:call, original_operation)
  end

  test "without qualities finds unassessed and zero-match films but excludes assigned films" do
    unassessed = imported_assignment_film(tmdb_id: 800001)
    zero = imported_assignment_film(tmdb_id: 800002)
    assigned = imported_assignment_film(tmdb_id: 800003)
    assessment_quality
    FilmKnowledge::AssignInitialFilmQualities.call(film_id: zero.id, client: Client.new(default_support: 0.1))
    FilmKnowledge::AssignInitialFilmQualities.call(film_id: assigned.id, client: Client.new)
    assert_equal [ unassessed.id, zero.id ].sort, Film.without_qualities.pluck(:id).sort
    assert_equal 1, assigned.film_qualities.count
  end
end
