require "test_helper"
require_relative "../../support/tmdb_http"

class FilmKnowledge::TypeSafeClientTest < ActiveSupport::TestCase
  include TmdbHttp

  def questions
    { "support" => { "type" => "noul", "instructions" => "Does the paragraph support the property?" } }
  end

  def response
    { "model" => "jev-1.14.0", "answers" => { "support" => { "type" => "noul", "noul" => 0.6 } }, "usage" => { "input_tokens" => 100, "output_tokens" => 10 } }
  end

  def client(payload: response, body: nil, code: 200, failure: nil, **options)
    @http = Connection.new(response: Response.new(code:, body: body || JSON.generate(payload)), failure:)
    FilmKnowledge::TypeSafeClient.new(token: "private-test-token", http_class: @http, **options)
  end

  def answer(client, questions: self.questions)
    client.answer(state: { "source_paragraphs" => [ "Public source text" ] }, questions:, phase: "quality-support")
  end

  test "posts explicit pinned model and typed questions without retries or credentials in payload" do
    assert_equal response, answer(client)
    request = @http.requests.sole
    assert_equal "POST", request.method
    assert_equal "/v1/systemone", request.path
    assert_equal "Bearer private-test-token", request["Authorization"]
    assert_equal "application/json", request["Content-Type"]
    payload = JSON.parse(request.body)
    assert_equal "jev-1.14.0", payload.fetch("model")
    assert_equal questions, payload.fetch("questions")
    refute_includes request.body, "private-test-token"
    assert_equal "api.typesafe.ai", @http.host
    assert_equal 0, @http.max_retries
  end

  test "missing unknown duplicate answers wrong type and invalid probabilities cannot pass" do
    invalid = [ response.merge("answers" => {}), response.merge("answers" => response.fetch("answers").merge("unknown" => {})),
      response.merge("model" => "jev-latest"), response.merge("usage" => {}), [], nil ]
    [ nil, "0.7", true, -0.1, 1.1 ].each do |value|
      invalid << response.merge("answers" => { "support" => { "type" => "noul", "noul" => value } })
    end
    invalid << response.merge("answers" => { "support" => { "type" => "choice", "noul" => 0.7 } })
    invalid.each do |payload|
      error = assert_raises(FilmKnowledge::AssignmentFailed) { answer(client(payload:)) }
      assert_includes [ :invalid_response, :unsupported_model ], error.reason
      assert_equal payload.to_json, error.provider_response.to_json
      assert_equal true, error.request_sent
    end
    duplicate = '{"model":"jev-1.14.0","answers":{"support":{"type":"noul","noul":0.6},"support":{"type":"noul","noul":0.9}},"usage":{"input_tokens":1,"output_tokens":1}}'
    error = assert_raises(FilmKnowledge::AssignmentFailed) { answer(client(body: duplicate)) }
    assert_equal :invalid_response, error.reason
  end

  test "evidence choices must resolve to known references and complete valid distributions" do
    questions = { "evidence" => { "type" => "choice", "instructions" => "Which passage supports the property?", "criteria" => { "P1" => "First passage", "P2" => "Second passage" } } }
    evidence = { "type" => "choice", "choice" => "P1", "probabilities" => { "P1" => 0.8, "P2" => 0.2 } }
    payload = response.merge("answers" => { "evidence" => evidence })
    assert_equal payload, answer(client(payload:), questions:)
    [ evidence.merge("choice" => "P9"), evidence.merge("probabilities" => { "P1" => 0.8 }), evidence.merge("probabilities" => { "P1" => -1, "P2" => 2 }) ].each do |value|
      error = assert_raises(FilmKnowledge::AssignmentFailed) { answer(client(payload: payload.merge("answers" => { "evidence" => value })), questions:) }
      assert_equal :invalid_response, error.reason
    end
  end

  test "provider failures are explicit sanitized and never retried" do
    { 401 => :authentication, 429 => :rate_limited, 413 => :too_large, 500 => :http_error }.each do |code, reason|
      error = assert_raises(FilmKnowledge::AssignmentFailed) { answer(client(body: "private response private-test-token", code:)) }
      assert_equal reason, error.reason
      assert_equal 1, @http.requests.size
      assert_nil error.cause
      refute_includes error.full_message, "private response"
      refute_includes error.full_message, "private-test-token"
    end
    error = assert_raises(FilmKnowledge::AssignmentFailed) { answer(client(failure: Net::ReadTimeout.new("private response"))) }
    assert_equal :timeout, error.reason
    error = assert_raises(FilmKnowledge::AssignmentFailed) { answer(client(body: "a" * 9.megabytes)) }
    assert_equal :too_large, error.reason
  end

  test "request and spend limits fail before an extra provider call" do
    limited = client(maximum_requests: 1)
    answer(limited)
    error = assert_raises(FilmKnowledge::AssignmentFailed) { answer(limited) }
    assert_equal :request_limit, error.reason
    assert_equal false, error.request_sent
    assert_equal 1, @http.requests.size
    limited = client(maximum_cost_usd: 0)
    error = assert_raises(FilmKnowledge::AssignmentFailed) { answer(limited) }
    assert_equal :budget_exceeded, error.reason
    assert_empty @http.requests
    limited = client
    error = assert_raises(FilmKnowledge::AssignmentFailed) { limited.answer(state: "a" * 600.kilobytes, questions:, phase: "quality-support") }
    assert_equal :too_large, error.reason
    assert_empty @http.requests
  end
end
