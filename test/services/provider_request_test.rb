require "test_helper"
require_relative "../support/tmdb_http"

class ProviderRequestTest < ActiveSupport::TestCase
  include TmdbHttp

  def request(response:, maximum_bytes: 1024, failure: nil)
    @http = Connection.new(response:, failure:)
    ProviderRequest.new(host: "new-provider.example", maximum_bytes:, http_class: @http)
  end

  test "a new host works with caller parameters headers and response limits" do
    transport = request(response: Response.new(code: 200, body: '{"result":"ok"}'))
    assert_equal({ "result" => "ok" }, transport.get(path: "/data", parameters: { q: "a & b" }, headers: { "X-API-Key" => "test-key" }))
    assert_equal "new-provider.example", @http.host
    assert_equal 443, @http.port
    assert @http.use_ssl
    sent = @http.requests.sole
    assert_equal "/data?q=a+%26+b", sent.path
    assert_equal "test-key", sent["X-API-Key"]
    assert_equal "application/json", sent["Accept"]
    assert_equal ProviderRequest::USER_AGENT, sent["User-Agent"]
    assert_equal [ 5, 10, 10, 0 ], [ @http.open_timeout, @http.read_timeout, @http.write_timeout, @http.max_retries ]
  end

  test "JSON shape and API error fields are returned for the client to interpret" do
    [ { "error" => { "code" => "maxlag" } }, [ 1, 2 ], "text", 42 ].each do |payload|
      transport = request(response: Response.new(code: 200, body: JSON.generate(payload)))
      assert_equal payload, transport.get(path: "/data", parameters: {})
    end
    transport = request(response: Response.new(code: 200, body: "null"))
    assert_nil transport.get(path: "/data", parameters: {})
  end

  test "caller size limit applies to headers and streamed body" do
    [ Response.new(code: 200, body: "{}", headers: { "Content-Length" => "9" }),
      Response.new(code: 200, body: [ "1234", "56789" ]) ].each do |response|
      transport = request(response:, maximum_bytes: 8)
      error = assert_raises(ProviderRequest::Error) { transport.get(path: "/data", parameters: {}) }
      assert_equal :too_large, error.reason
    end
    transport = request(response: Response.new(code: 200, body: '{"a":1}'), maximum_bytes: 7)
    assert_equal({ "a" => 1 }, transport.get(path: "/data", parameters: {}))
  end

  test "HTTP errors have transport reasons without provider knowledge or raw content" do
    { 301 => :http_error, 401 => :authentication, 403 => :authentication, 404 => :not_found,
      429 => :rate_limited, 500 => :http_error }.each do |code, reason|
      transport = request(response: Response.new(code:, body: "private-response"))
      error = assert_raises(ProviderRequest::Error) { transport.get(path: "/data", parameters: {}, headers: { "Authorization" => "private-token" }) }
      assert_equal reason, error.reason
      assert_equal 1, @http.requests.size
      assert_nil error.cause
      refute_includes error.full_message, "private-response"
      refute_includes error.full_message, "private-token"
    end
  end

  test "invalid JSON and network errors use sanitized transport errors" do
    transport = request(response: Response.new(code: 200, body: "private-response"))
    error = assert_raises(ProviderRequest::Error) { transport.get(path: "/data", parameters: {}) }
    assert_equal :invalid_response, error.reason
    [ [ Net::ReadTimeout, :timeout ], [ SocketError, :transport ] ].each do |failure, reason|
      transport = request(response: nil, failure: failure.new("private-response"))
      error = assert_raises(ProviderRequest::Error) { transport.get(path: "/data", parameters: {}) }
      assert_equal reason, error.reason
      assert_nil error.cause
      refute_includes error.full_message, "private-response"
    end
  end
end
