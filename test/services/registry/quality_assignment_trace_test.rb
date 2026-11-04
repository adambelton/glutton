require "test_helper"
require_relative "../../support/quality_assessment_sources"
require_relative "../../support/tmdb_http"

class Registry::QualityAssignmentTraceTest < ActiveSupport::TestCase
  include QualityAssessmentSources

  class Http < TmdbHttp::Connection
    def initialize(failure: nil)
      super(response: nil, failure:)
      @client = QualityAssessmentSources::Client.new
    end

    def request(request)
      @requests << request
      raise @failure if @failure
      payload = JSON.parse(request.body)
      response = @client.answer(state: payload.fetch("state"), questions: payload.fetch("questions"), phase: "fake-http")
      yield TmdbHttp::Response.new(code: 200, body: response.to_json)
    end
  end

  setup do
    @exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    @provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    @provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(@exporter))
  end

  teardown { @provider.shutdown }

  def client(http: Http.new)
    Registry::TypeSafeClient.new(token: "private-test-key", http_class: http, tracer: @provider.tracer("glutton.registry", "1"))
  end

  test "assignment records exact requests answers usage cost and hierarchy without secrets" do
    film = imported_assignment_film
    assessment_quality
    result = Registry::AssignInitialFilmQualities.call(film_id: film.id, client: client, tracer_provider: @provider)
    spans = @exporter.finished_spans
    root = spans.find { |span| span.name == "assign-initial-film-qualities" }
    generations = spans.reject { |span| span == root }
    assert_equal 2, generations.size
    evaluation = result.fetch(:film_quality_eval).reload
    assert_equal evaluation.id, root.attributes.fetch("film_quality_eval_id")
    calls = evaluation.output.fetch("calls")
    generations.each_with_index do |generation, index|
      assert_equal JSON.parse(generation.attributes.fetch("langfuse.observation.input")), calls[index].fetch("request")
      assert_equal JSON.parse(generation.attributes.fetch("langfuse.observation.output")), calls[index].fetch("response")
    end
    assert_equal root.trace_id.unpack1("H*"), result.fetch(:film_quality_eval).output.fetch("trace_id")
    root_output = JSON.parse(root.attributes.fetch("langfuse.observation.output"))
    assert_equal Registry::InitialQualityAssessment::POLICY, root_output.fetch("selection_policy")
    assert_equal 0.6, root_output.fetch("minimum_support")
    assert_equal result.fetch(:film_quality_eval).output.fetch("support"), root_output.fetch("support")
    assert_equal result.fetch(:film_quality_eval).output.fetch("evidence"), root_output.fetch("evidence")
    generations.each do |span|
      assert_equal root.span_id, span.parent_span_id
      assert_equal root.trace_id, span.trace_id
      assert_equal "generation", span.attributes["langfuse.observation.type"]
      assert_equal "jev-1.14.0", span.attributes["langfuse.observation.model.name"]
      assert JSON.parse(span.attributes["langfuse.observation.input"]).fetch("questions").any?
      assert JSON.parse(span.attributes["langfuse.observation.output"]).fetch("answers").any?
      assert_equal({ "input" => 100, "output" => 10 }, JSON.parse(span.attributes["langfuse.observation.usage_details"]))
      assert_in_delta 100 * Registry::TypeSafeClient::INPUT_TOKEN_PRICE, JSON.parse(span.attributes["langfuse.observation.cost_details"]).fetch("input")
    end
    spans.each do |span|
      refute_includes span.attributes.to_json, "private-test-key"
      assert_empty Array(span.events)
    end
  end

  test "provider failure has error spans and never exports raw exception text" do
    film = imported_assignment_film
    assessment_quality
    error = assert_raises(Registry::AssignmentFailed) do
      Registry::AssignInitialFilmQualities.call(film_id: film.id,
        client: client(http: Http.new(failure: Net::ReadTimeout.new("private-test-key private-response"))), tracer_provider: @provider)
    end
    assert_equal :timeout, error.reason
    evaluation = film.film_quality_evals.sole
    assert_equal "failed", evaluation.output.fetch("status")
    assert_equal 1, evaluation.output.fetch("call_count")
    assert_equal "timeout", evaluation.output.fetch("calls").sole.fetch("error").fetch("reason")
    assert_empty film.reload.film_qualities
    @exporter.finished_spans.each do |span|
      assert_equal OpenTelemetry::Trace::Status::ERROR, span.status.code
      assert_empty Array(span.events)
      refute_includes span.attributes.to_json, "private-test-key"
      refute_includes span.status.description, "private-response"
    end
  end

  test "a request blocked before sending is retained without counting a provider call" do
    film = imported_assignment_film
    assessment_quality
    http = Http.new
    limited = Registry::TypeSafeClient.new(token: "private-test-key", http_class: http, maximum_requests: 0)
    assert_raises(Registry::AssignmentFailed) do
      Registry::AssignInitialFilmQualities.call(film_id: film.id, client: limited, tracer_provider: @provider)
    end
    evaluation = film.film_quality_evals.sole
    assert_empty http.requests
    assert_equal 0, evaluation.output.fetch("call_count")
    assert_equal "not_sent", evaluation.output.fetch("calls").sole.fetch("status")
  end

  test "a rejected parsed response is retained with its failed evaluation" do
    film = imported_assignment_film
    assessment_quality
    response = { "model" => "jev-1.14.0", "answers" => {}, "usage" => { "input_tokens" => 100, "output_tokens" => 10 } }
    http = TmdbHttp::Connection.new(response: TmdbHttp::Response.new(code: 200, body: response.to_json))
    assert_raises(Registry::AssignmentFailed) do
      Registry::AssignInitialFilmQualities.call(film_id: film.id, client: client(http:), tracer_provider: @provider)
    end
    evaluation = film.film_quality_evals.sole
    assert_equal response, evaluation.output.fetch("calls").sole.fetch("response")
    assert_equal false, evaluation.output.fetch("usage_complete")
    assert_equal "invalid_response", evaluation.application.fetch("reason")
    assert_empty film.reload.film_qualities
  end
end
