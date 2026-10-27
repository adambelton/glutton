require "test_helper"
require "tmpdir"

class FilmKnowledge::GenerateAnalysisTest < ActiveSupport::TestCase
  setup do
    @film = Film.create!(title: "Alien", tmdb_id: 348, metadata: { tmdb: { details: { overview: "A crew encounters danger." }, fetched_at: "2026-10-27" } })
    @document = { "content" => { "format_version" => 1, "context" => "Cut unknown; TMDB overview only.",
      "narrative" => [ { "id" => "N1", "text" => "TMDB reports danger to a crew.", "source_ids" => [ "TMDB" ] } ],
      "moments" => [], "synthesis" => "Interpretation: isolation may support tension.",
      "sources" => [ { "id" => "TMDB", "reference" => "https://www.themoviedb.org/movie/348" } ],
      "gaps" => [ "Scene details and audience experiences are unknown." ] }, "quality_candidates" => [] }
    @response = Struct.new(:status, :model, :usage, :output_text, :output).new("completed", "actual-model", nil, @document.to_json, [])
    @requests = []
    @responses = Object.new
    test = self
    @responses.define_singleton_method(:create) do |**request|
      test.instance_variable_get(:@requests) << request
      test.instance_variable_get(:@during_request)&.call
      test.instance_variable_get(:@response)
    end
    @prompt = { "name" => "film-analysis", "version" => 2, "prompt" => "Managed instructions", "sha256" => "test-hash" }
    prompt = @prompt
    @prompt_source = Object.new
    @prompt_source.define_singleton_method(:call) { |**| prompt }
    @exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    @provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    @provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(@exporter))
    @directory = Dir.mktmpdir
    @generator = FilmKnowledge::GenerateAnalysis.new(client: Struct.new(:responses).new(@responses), provider: @provider, prompt_source: @prompt_source)
  end

  teardown do
    @provider.shutdown
    FileUtils.remove_entry(@directory)
  end

  def generate
    @generator.call(film: @film, model: "chosen-model", max_output_tokens: 1024, output_directory: @directory, label: "development")
  end

  def artifact
    JSON.parse(File.read(@generator.artifact_path))
  end

  test "saves an incomplete unpublished draft with exact input prompt response and nested trace" do
    assert_no_difference [ "FilmQuality.count", "AnalysisQuality.count" ] do
      analysis = assert_difference("FilmAnalysis.count", 1) { generate }
      assert_nil analysis.published_at
      assert_equal @document["content"], analysis.content
      assert_empty analysis.quality_candidates
    end
    request = @requests.sole
    assert_equal "A crew encounters danger.", JSON.parse(request[:input]).dig("film", "metadata", "tmdb", "details", "overview")
    assert_equal 1024, request[:max_output_tokens]
    assert_equal false, request[:store]
    assert request.dig(:text, :format, :strict)
    assert_equal @prompt, artifact["prompt"]
    assert_equal @response.output_text, artifact.dig("response", "output_text")
    assert_equal "saved", artifact["outcome"]
    generation = @exporter.finished_spans.find { |span| span.name == "generate-film-analysis-response" }
    root = @exporter.finished_spans.find { |span| span.name == "generate-film-analysis" }
    assert_equal root.span_id, generation.parent_span_id
    assert_equal 2, generation.attributes["langfuse.observation.prompt.version"]
    assert_equal "actual-model", generation.attributes["langfuse.observation.model.name"]
    assert_equal "generation", generation.attributes["langfuse.observation.type"]
  end

  test "locked SDK response preserves raw output and actual token usage" do
    message = OpenAI::Models::Responses::ResponseOutputMessage.new(id: "message", role: :assistant, status: :completed,
      content: [ OpenAI::Models::Responses::ResponseOutputText.new(text: @document.to_json, annotations: []) ])
    @response = OpenAI::Models::Responses::Response.new(id: "response", model: "returned-model", status: :completed, output: [ message ],
      usage: OpenAI::Models::Responses::ResponseUsage.new(input_tokens: 20, output_tokens: 30, total_tokens: 50))
    assert_equal @document["content"], generate.content
    assert_equal @document.to_json, artifact.dig("response", "output", 0, "content", 0, "text")
    generation = @exporter.finished_spans.find { |span| span.name == "generate-film-analysis-response" }
    assert_equal({ "input" => 20, "output" => 30, "total" => 50 }, JSON.parse(generation.attributes["langfuse.observation.usage_details"]))
  end

  test "refusal is not saved even with a completed response" do
    @response.output = [ { type: "message", content: [ { type: "refusal", refusal: "Cannot comply" } ] } ]
    error = assert_raises(FilmKnowledge::GenerationFailed) { generate }
    assert_equal :refused_response, error.reason
    assert_empty @film.film_analyses
  end

  test "published analyses cannot be regenerated and revisions remain manual" do
    @document["content"]["moments"] = [ { "id" => "M1", "text" => "Overview event", "source_ids" => [ "TMDB" ] } ]
    @document["quality_candidates"] = [ { "name" => "Dread", "dimension" => FilmQuality::Dimensions::ALL.first, "evidence_references" => [ "M1" ] } ]
    @response.output_text = @document.to_json
    draft = generate
    @film.publish_analysis!
    @prompt_source.define_singleton_method(:call) { |**| raise "Prompt must not be retrieved" }
    assert_raises(FilmKnowledge::GenerationUnavailable) { generate }
    assert_equal 1, @requests.size
    assert_empty @film.film_analyses.draft
    assert draft.reload.published_at
    revision = @film.edit_analysis!(content: { "manual" => "Revised" })
    assert_not_equal draft.id, revision.id
    assert_nil revision.published_at
    assert_equal draft, @film.film_analyses.current.sole
  end

  test "existing vocabulary candidates persist without resolving or publishing" do
    quality = FilmQuality.create!(name: "Dread", dimension: FilmQuality::Dimensions::ALL.first)
    @document["quality_candidates"] = [ { "film_quality_id" => quality.id, "name" => nil, "dimension" => quality.dimension, "evidence_references" => [ "N1" ] } ]
    @response.output_text = @document.to_json
    assert_no_difference [ "FilmQuality.count", "AnalysisQuality.count" ] do
      assert_equal quality.id, generate.quality_candidates.sole["film_quality_id"]
    end
  end

  test "invalid JSON structures sources references and candidates cannot save a partial seed" do
    invalid = [ nil, [], {}, @document.deep_merge("content" => { "sources" => [ { "id" => "invented", "reference" => "review" } ] }),
      @document.deep_merge("content" => { "moments" => [ { "id" => "M1", "text" => "invented", "source_ids" => [ "other" ] } ] }),
      @document.merge("quality_candidates" => [ { "name" => "Dread", "dimension" => "wrong", "evidence_references" => [ "N1" ] } ]),
      @document.merge("quality_candidates" => [ { "film_quality_id" => 999999, "dimension" => FilmQuality::Dimensions::ALL.first, "evidence_references" => [ "N1" ] } ]),
      @document.merge("quality_candidates" => [ { "name" => "Dread", "dimension" => FilmQuality::Dimensions::ALL.first, "evidence_references" => [ "missing" ] } ]) ]
    invalid.each do |document|
      @response.output_text = document.to_json
      assert_raises(FilmKnowledge::GenerationFailed) { generate }
      assert_empty @film.film_analyses
    end
    @response.output_text = "broken JSON"
    assert_raises(FilmKnowledge::GenerationFailed) { generate }
    assert_equal invalid.size + 1, Dir.children(@directory).size
  end

  test "existing draft is refused before prompt retrieval or generation" do
    draft = @film.edit_analysis!(content: { "editorial" => "Keep" })
    @prompt_source.define_singleton_method(:call) { |**| raise "Prompt must not be retrieved" }
    error = assert_raises(FilmKnowledge::GenerationUnavailable) { generate }
    assert_equal I18n.t("film_knowledge.errors.generation_unavailable", raise: true), error.message
    assert_empty @requests
    assert_equal "Keep", draft.reload.content["editorial"]
    assert_equal "generation_unavailable", artifact["outcome"]
  end

  test "failures preserve imported data and allow an explicit retry" do
    @response.status = "incomplete"
    assert_raises(FilmKnowledge::GenerationFailed) { generate }
    assert_empty @film.film_analyses
    assert @film.reload.metadata.dig("tmdb", "details")
    @response.status = "completed"
    assert_difference("FilmAnalysis.count", 1) { generate }
    assert_equal 2, @requests.size
  end

  test "provider and prompt failures are sanitized and never retried" do
    @during_request = -> { raise "secret request body" }
    assert_raises(RuntimeError) { generate }
    assert_equal 1, @requests.size
    assert_not_includes File.read(@generator.artifact_path), "secret request body"
    @exporter.finished_spans.each { |span| assert_empty Array(span.events) }
    @prompt_source.define_singleton_method(:call) { |**| raise FilmKnowledge::GenerationFailed.new(:prompt_retrieval) }
    assert_raises(FilmKnowledge::GenerationFailed) { generate }
    assert_equal 1, @requests.size
  end

  test "missing source metadata fails before prompt retrieval or generation" do
    @film.update!(metadata: {})
    @prompt_source.define_singleton_method(:call) { |**| raise "Prompt must not be retrieved" }
    assert_raises(FilmKnowledge::GenerationUnavailable) { generate }
    assert_empty @requests
    assert_empty @film.film_analyses
  end

  test "deleted films and missing metadata do not call the provider" do
    @film.destroy!
    assert_raises(ActiveRecord::RecordNotFound) { generate }
    assert_empty @requests
  end

  test "export failure never undoes saved work or repeats the request" do
    @provider.define_singleton_method(:force_flush) { |**| raise "export secret" }
    assert_difference("FilmAnalysis.count", 1) { generate }
    assert_equal 1, @requests.size
    assert_equal "failed", artifact["trace_export"]
    assert_equal "saved", artifact["outcome"]
  end
end
