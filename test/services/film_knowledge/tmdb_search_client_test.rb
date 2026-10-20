require "test_helper"
require_relative "../../support/tmdb_http"

class FilmKnowledge::TmdbSearchClientTest < ActiveSupport::TestCase
  include TmdbHttp

  test "encodes one fixed TLS search request with optional year and explicit paging" do
    client = fake_http(body: '{"page":2,"results":[],"total_pages":3,"total_results":40}')
    query = " 日本語  & year=2000?+/# "
    client.search(query:, page: 2, primary_release_year: 1982)
    assert_equal "api.themoviedb.org", @http.host
    assert_equal 443, @http.port
    assert @http.use_ssl
    assert_equal [ 5, 10, 10, 0 ], [ @http.open_timeout, @http.read_timeout, @http.write_timeout, @http.max_retries ]
    assert_equal 1, @http.requests.size
    request = @http.requests.first
    uri = URI(request.path)
    assert_equal "/3/search/movie", uri.path
    assert_equal({ "query" => query.strip, "page" => "2", "language" => "en-US", "include_adult" => "false", "primary_release_year" => "1982" }, URI.decode_www_form(uri.query).to_h)
    assert_equal "Bearer fake-test-token", request["Authorization"]
    assert_equal "application/json", request["Accept"]
    assert_equal "GET", request.method

    fake_http.search(query: "Alien")
    assert_equal({ "query" => "Alien", "page" => "1", "language" => "en-US", "include_adult" => "false" }, URI.decode_www_form(URI(@http.requests.first.path).query).to_h)
  end

  test "invalid inputs precede missing credential failures" do
    client = fake_http(token: nil)
    assert_raises(FilmKnowledge::InvalidTmdbSearch) { client.search(query: "") }
    assert_raises(FilmKnowledge::InvalidTmdbSearch) { FilmKnowledge::TmdbClient.search(query: nil) }
    assert_empty @http.requests
    [ nil, "", " \t", "secret\nheader" ].each do |token|
      client = fake_http(token:)
      assert_raises(FilmKnowledge::TmdbConfigurationError) { client.search(query: "Alien") }
      assert_empty @http.requests
    end
  end

  test "search transport JSON and redirect errors are sanitized without retries" do
    [ Net::OpenTimeout, Net::ReadTimeout, SocketError, EOFError, Net::HTTPBadResponse ].each do |type|
      client = fake_http(failure: type.new("private-query private-body fake-test-token"))
      error = assert_raises(FilmKnowledge::TmdbUnavailable) { client.search(query: "private-query") }
      assert_equal(type <= Timeout::Error ? :timeout : :transport, error.reason)
      assert_nil error.cause
      assert_equal 1, @http.requests.size
      assert_safe(error)
    end
    [ nil, "private-query private-body fake-test-token", "[]", "null", '"bad"' ].each do |body|
      client = fake_http(body:)
      error = assert_raises(FilmKnowledge::InvalidTmdbResponse) { client.search(query: "private-query") }
      assert_nil error.cause
      assert_safe(error)
    end
    client = fake_http(code: 302, body: "private-body")
    error = assert_raises(FilmKnowledge::TmdbUnavailable) { client.search(query: "private-query") }
    assert_equal :http_error, error.reason
    assert_equal 1, @http.requests.size
    assert_safe(error)
  end

  private

  def assert_safe(error)
    [ "private-query", "private-body", "fake-test-token", "Authorization" ].each do |marker|
      refute_includes error.full_message, marker
    end
  end
end
