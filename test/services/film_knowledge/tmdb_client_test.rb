require "test_helper"
require "stringio"
require_relative "../../support/tmdb_http"

class FilmKnowledge::TmdbClientTest < ActiveSupport::TestCase
  include TmdbHttp

  test "fixed TLS request uses bearer header and bounded timeouts without retries" do
    assert_equal({ "id" => 348, "title" => "Alien" }, fake_http.movie(tmdb_id: 348))
    assert_equal "api.themoviedb.org", @http.host
    assert_equal 443, @http.port
    assert @http.use_ssl
    assert_equal [ 5, 10, 10, 0 ], [ @http.open_timeout, @http.read_timeout, @http.write_timeout, @http.max_retries ]
    assert_equal 1, @http.requests.size
    request = @http.requests.first
    assert_equal "/3/movie/348?language=en-US", request.path
    assert_equal "Bearer fake-test-token", request["Authorization"]
    assert_equal "application/json", request["Accept"]
    assert_equal "GET", request.method
  end

  test "invalid identifiers and credentials fail before HTTP" do
    [ nil, 0, -1, 1.0, "348", "https://example.test" ].each do |id|
      client = fake_http
      assert_raises(FilmKnowledge::InvalidTmdbId) { client.movie(tmdb_id: id) }
      assert_empty @http.requests
    end
    [ nil, "", " \t", "secret\nheader" ].each do |token|
      client = fake_http(token:)
      assert_raises(FilmKnowledge::TmdbConfigurationError) { client.movie(tmdb_id: 348) }
      assert_empty @http.requests
    end
  end

  test "HTTP failures including redirects never retry or expose raw data" do
    { 401 => :authentication, 403 => :authentication, 429 => :rate_limited,
      301 => :http_error, 302 => :http_error, 500 => :http_error, 503 => :http_error }.each do |code, reason|
      client = fake_http(code:, body: "private-body fake-test-token")
      error = assert_raises(FilmKnowledge::TmdbUnavailable) { client.movie(tmdb_id: 348) }
      assert_equal reason, error.reason
      assert_equal 1, @http.requests.size
      assert_safe(error)
    end
    client = fake_http(code: 404, body: "private-body")
    assert_safe(assert_raises(FilmKnowledge::TmdbNotFound) { client.movie(tmdb_id: 348) })
  end

  test "transport and JSON errors sanitize their entire exception chain" do
    [ Net::OpenTimeout, Net::ReadTimeout, SocketError, EOFError, Errno::ECONNRESET, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError ].each do |type|
      client = fake_http(failure: type.new("private-body fake-test-token"))
      error = assert_raises(FilmKnowledge::TmdbUnavailable) { client.movie(tmdb_id: 348) }
      assert_equal(type <= Timeout::Error ? :timeout : :transport, error.reason)
      assert_equal 1, @http.requests.size
      assert_nil error.cause
      assert_safe(error)
    end
    [ nil, "private-body fake-test-token", "[]", "null", "42", '"private-body"' ].each do |body|
      client = fake_http(body:)
      error = assert_raises(FilmKnowledge::InvalidTmdbResponse) { client.movie(tmdb_id: 348) }
      assert_nil error.cause
      assert_safe(error)
    end
  end

  private

  def assert_safe(error)
    refute_includes error.full_message, "fake-test-token"
    refute_includes error.full_message, "private-body"
    refute_includes error.full_message, "Authorization"
  end
end
