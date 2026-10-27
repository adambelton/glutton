require "test_helper"

class FilmKnowledge::GeneratedAnalysisTest < ActiveSupport::TestCase
  setup do
    @document = JSON.parse(file_fixture("researched_analysis.json").read)
  end

  def parse
    FilmKnowledge::GeneratedAnalysis.parse!(@document.to_json, vocabulary: [])
  end

  def claim
    @document["content"]["narrative"].first
  end

  test "two independent sources retain factual claim and precise supporting passages" do
    result = parse
    assert_equal @document["content"], result[:content]
    assert_empty result[:quality_candidates]
  end

  test "source support is accepted without a page-open history" do
    assert_equal @document["content"], parse[:content]
    @document["content"]["sources"].first["kind"] = "screenplay"
    @document["content"]["sources"].first["film_version"] = "Draft screenplay; retained event corroborated by finished-film account"
    assert_equal "screenplay", parse[:content]["sources"].first["kind"]
  end

  test "OpenSubtitles source domains and subdomains are excluded" do
    %w[opensubtitles.com www.opensubtitles.org api.opensubtitles.com OpenSubtitles.COM].each do |host|
      reference = "https://#{host}/film/348"
      @document["content"]["sources"].last["reference"] = reference
      assert_raises(FilmKnowledge::GenerationFailed) { parse }
    end
    reference = "https://opensubtitles.com.example/independent-account"
    @document["content"]["sources"].last["reference"] = reference
    assert_equal reference, parse[:content]["sources"].last["reference"]
  end

  test "malformed source URLs are not admitted" do
    @document["content"]["sources"].first["reference"] = "not a URL"
    assert_raises(FilmKnowledge::GenerationFailed) { parse }
  end

  test "copied accounts and two fragments of one URL cannot satisfy factual corroboration" do
    sources = @document["content"]["sources"]
    sources.last["origin"] = sources.first["origin"].upcase
    claim["independent_support_count"] = 1
    assert_raises(FilmKnowledge::GenerationFailed) { parse }
    sources.last["origin"] = "independent"
    sources.last["reference"] = sources.first["reference"] + "#another-section"
    assert_raises(FilmKnowledge::GenerationFailed) { parse }
  end

  test "a single source cannot support a factual entry" do
    claim["source_ids"] = [ "S1" ]
    claim["support"] = [ claim["support"].first ]
    claim["independent_support_count"] = 1
    assert_raises(FilmKnowledge::GenerationFailed) { parse }
  end

  test "attributed experience retains independent account count without claiming prevalence" do
    claim.merge!("text" => "The first reviewer reports feeling dread during the encounter.", "kind" => "experiential",
      "source_ids" => [ "S1" ], "support" => [ claim["support"].first.merge("basis" => "experience", "excerpt" => "I felt dread.") ],
      "independent_support_count" => 1)
    assert_equal 1, parse[:content]["narrative"].first["independent_support_count"]
    claim["source_ids"] << "S2"
    claim["support"] << { "source_id" => "S2", "basis" => "experience", "excerpt" => "This scene filled me with dread.", "locator" => "Review, paragraph 4" }
    claim["independent_support_count"] = 2
    assert_equal 2, parse[:content]["narrative"].first["independent_support_count"]
    claim["independent_support_count"] = 3
    assert_raises(FilmKnowledge::GenerationFailed) { parse }
  end

  test "unknown kinds missing extracts and dangling evidence are rejected" do
    [ [ "kind", "plausible" ], [ "source_ids", [ "missing" ] ], [ "independent_support_count", 0 ] ].each do |key, value|
      original = claim[key]
      claim[key] = value
      assert_raises(FilmKnowledge::GenerationFailed) { parse }
      claim[key] = original
    end
    claim["support"].first["excerpt"] = ""
    assert_raises(FilmKnowledge::GenerationFailed) { parse }
  end

  test "subtitle corroboration needs a known matched version and cue locator and cannot prove visuals" do
    source = @document["content"]["sources"].last
    source["kind"] = "subtitles"
    support = claim["support"].last
    support.merge!("basis" => "dialogue", "locator" => "00:12:01,000 --> 00:12:03,500; cue 120")
    assert_raises(FilmKnowledge::GenerationFailed) { parse }
    source["film_version"] = "1979 theatrical release"
    assert_raises(FilmKnowledge::GenerationFailed) { parse }
    source["version_match"] = "matched"
    assert_equal "subtitles", parse[:content]["sources"].last["kind"]
    support["locator"] = "probably the egg scene"
    assert_raises(FilmKnowledge::GenerationFailed) { parse }
    support["locator"] = "00:12:01,000 --> 00:12:03,500; cue 120"
    support["basis"] = "visual"
    assert_raises(FilmKnowledge::GenerationFailed) { parse }
    support["basis"] = "audible"
    assert_raises(FilmKnowledge::GenerationFailed) { parse }
    source["kind"] = "captions"
    assert_equal "audible", parse[:content]["narrative"].first["support"].last["basis"]
  end

  test "a source with no retained claims saves only with explicit gaps" do
    @document["content"]["narrative"] = []
    assert_empty parse[:content]["narrative"]
    @document["content"]["gaps"] = []
    assert_raises(FilmKnowledge::GenerationFailed) { parse }
  end
end
