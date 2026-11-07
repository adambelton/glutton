require "test_helper"
require_relative "../../support/quality_assessment_sources"

class Registry::InitialQualityAssessmentTest < ActiveSupport::TestCase
  include QualityAssessmentSources

  def source
    { "title" => "Fixture film", "tmdb_id" => 348, "wikidata_id" => "Q1", "tmdb_metadata" => { "details" => {} }, "wikipedia_context" => wikipedia_context }
  end

  def definition(id:, category_id:)
    { "id" => id, "name" => "Quality #{id}", "quality_category_id" => category_id, "match_rule" => "A supported property.", "not_sufficient" => "An unsupported property." }
  end

  test "one support request selects beyond twenty without collecting paragraph evidence" do
    categories = 12.times.map { |index| { "id" => index + 1, "name" => "Category #{index}", "maximum_qualities" => 3 } }
    definitions = categories.flat_map { |category| 4.times.map { |index| definition(id: category.fetch("id") * 10 + index, category_id: category.fetch("id")) } }
    client = Client.new
    assessment = Registry::InitialQualityAssessment.new(source:, definitions:, categories:).call(client:)
    assert_equal 36, assessment.result.fetch("selected_quality_ids").size
    assert_equal categories.flat_map { |category| 3.times.map { |index| category.fetch("id") * 10 + index } }, assessment.result.fetch("selected_quality_ids")
    assert_equal 1, client.requests.size
    assert_equal 48, client.requests.sole.fetch(:questions).size
    assert client.requests.sole.fetch(:questions).values.all? { |question| question.fetch("type") == "noul" }
    assert_empty assessment.result.fetch("evidence")
    assert_empty assessment.result.keys & %w[selection_policy evidence_policy]
    assert_equal 48, assessment.result.fetch("support").size
  end

  test "zero differing caps threshold equality and ties are deterministic without padding" do
    categories = [ { "id" => 1, "maximum_qualities" => 0 }, { "id" => 2, "maximum_qualities" => 2 }, { "id" => 3, "maximum_qualities" => 5 } ]
    definitions = [ definition(id: 1, category_id: 1), definition(id: 20, category_id: 2), definition(id: 21, category_id: 2),
      definition(id: 22, category_id: 2), definition(id: 30, category_id: 3), definition(id: 31, category_id: 3) ].reverse
    client = Client.new(support: { "quality_20" => 0.6, "quality_21" => 0.6, "quality_22" => 0.6, "quality_30" => 0.59, "quality_31" => 0.8 })
    assessment = Registry::InitialQualityAssessment.new(source:, definitions:, categories:).call(client:)
    assert_equal [ 20, 21, 31 ], assessment.result.fetch("selected_quality_ids")
    assert_empty assessment.result.fetch("evidence")
    decisions = assessment.result.fetch("selection_decisions").index_by { |decision| decision.fetch("quality_id") }
    assert_equal "category_ceiling", decisions.fetch(1).fetch("reason")
    assert_equal "category_ceiling", decisions.fetch(22).fetch("reason")
    assert_equal "below_threshold", decisions.fetch(30).fetch("reason")
    assert_equal assessment.result.fetch("selected_quality_ids").sort, decisions.values.select { |decision| decision.fetch("selected") }.map { |decision| decision.fetch("quality_id") }.sort
  end

  test "completion timestamp and full call record stay stable after assessment" do
    assessment = Registry::InitialQualityAssessment.new(source:, definitions: [ definition(id: 1, category_id: 1) ],
      categories: [ { "id" => 1, "maximum_qualities" => 1 } ]).call(client: Client.new)
    completed_at = assessment.result.fetch("assessed_at")
    travel 5.minutes do
      assert_equal completed_at, assessment.result.fetch("assessed_at")
      assert_equal 1, assessment.result.fetch("call_count")
      assert_equal [ "quality-support" ], assessment.result.fetch("calls").map { |call| call.fetch("phase") }
    end
  end
end
