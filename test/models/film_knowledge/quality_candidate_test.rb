require "test_helper"
require_relative "../../support/film_analysis_helpers"

class FilmKnowledge::QualityCandidateTest < ActiveSupport::TestCase
  include FilmAnalysisHelpers

  test "proposals expose identity and evidence without persisting vocabulary" do
    candidate = proposal("name" => "Sustained dread", "dimension" => FilmQuality::Dimensions::EMOTIONAL_CHARACTER,
      "evidence_references" => [ "M1" ])
    assert candidate.valid?
    assert_equal "Sustained dread", candidate.name
    assert_equal [ "M1" ], candidate.evidence_references
    assert proposal("film_quality_id" => 1, "evidence_references" => [ "N1" ]).valid?
  end

  test "ambiguous identities malformed IDs and missing evidence are rejected" do
    [ { "film_quality_id" => "1" }, { "film_quality_id" => -1 },
      { "film_quality_id" => 1, "name" => "Conflicting name" },
      { "name" => "Proposal", "dimension" => "unknown" },
      { "film_quality_id" => 1, "evidence_references" => [ "missing" ] } ].each do |attributes|
      candidate = proposal({ "evidence_references" => [ "M1" ] }.merge(attributes))
      assert_raises(ActiveModel::ValidationError) { candidate.validate! }
    end
  end

  private

  def proposal(attributes)
    FilmKnowledge::QualityCandidate.new(attributes, analysis_content: FilmKnowledge::AnalysisContent.new(analysis_content))
  end
end
