require "test_helper"
require_relative "../../support/film_analysis_helpers"

class FilmKnowledge::AnalysisContentTest < ActiveSupport::TestCase
  include FilmAnalysisHelpers

  test "content exposes the evidence identifiers used by candidate proposals" do
    content = FilmKnowledge::AnalysisContent.new(analysis_content)
    assert content.valid?
    assert_equal [ "N1", "M1" ], content.evidence_ids
  end

  test "malformed documents and unsupported versions are incomplete" do
    [ nil, [], "text", {}, analysis_content.merge("format_version" => 999),
      analysis_content.merge("sources" => [ nil ]), analysis_content.merge("narrative" => [ nil ]),
      analysis_content.merge("sources" => analysis_content["sources"] * 2),
      analysis_content.merge("gaps" => nil) ].each do |document|
      assert_not FilmKnowledge::AnalysisContent.new(document).valid?
    end
  end
end
