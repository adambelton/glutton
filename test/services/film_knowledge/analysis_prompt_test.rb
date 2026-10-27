require "test_helper"

class FilmKnowledge::AnalysisPromptTest < ActiveSupport::TestCase
  setup do
    @body = { "name" => "film-analysis", "type" => "text", "version" => 2, "prompt" => "TMDB instructions", "config" => { "contract" => "tmdb-analysis-v1" } }
    @arguments = []
    @runner = Object.new
    test = self
    @runner.define_singleton_method(:capture3) do |*arguments|
      test.instance_variable_get(:@arguments) << arguments
      [ { body: test.instance_variable_get(:@body) }.to_json, "private stderr", Struct.new(:success?).new(true) ]
    end
  end

  def fetch(**selector)
    FilmKnowledge::AnalysisPrompt.call(**selector, command_runner: @runner, environment: { "LANGFUSE_BASE_URL" => "https://example.test" })
  end

  test "one retrieval keeps resolved identity exact instructions and hash together" do
    prompt = fetch(label: "development")
    assert_equal "TMDB instructions", prompt["prompt"]
    assert_equal 2, prompt["version"]
    assert_equal Digest::SHA256.hexdigest(prompt["prompt"]), prompt["sha256"]
    assert_equal 1, @arguments.size
    assert_equal [ "--label", "development", "--json" ], @arguments.sole.last(3)
    assert_equal prompt, fetch(version: 2)
  end

  test "legacy Markdown and incorrect prompt identities fail before generation" do
    [ { "config" => {} }, { "name" => "other" }, { "type" => "chat" }, { "prompt" => "" }, { "version" => "2" } ].each do |changes|
      original = @body
      @body = original.merge(changes)
      assert_raises(FilmKnowledge::GenerationFailed) { fetch(label: "development") }
      @body = original
    end
    assert_raises(FilmKnowledge::GenerationFailed) { fetch(version: 3) }
  end

  test "only explicit version or development selector is allowed" do
    [ {}, { label: "production" }, { label: "latest" }, { version: 0 }, { version: 2, label: "development" } ].each do |selector|
      assert_raises(ArgumentError) { fetch(**selector) }
    end
    assert_empty @arguments
  end
end
