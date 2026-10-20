require "test_helper"
require "stringio"
require_relative "../../support/tmdb_http"

class FilmKnowledge::SearchTmdbFilmsTest < ActiveSupport::TestCase
  include TmdbHttp

  def response(results: [], page: 1, total_pages: 1, total_results: results.size)
    { "page" => page, "total_pages" => total_pages, "total_results" => total_results, "results" => results }
  end

  def search(payload, **options)
    client = fake_http(body: JSON.generate(payload))
    FilmKnowledge::SearchTmdbFilms.call(query: "The Thing", client:, **options)
  end

  test "one page preserves provider order and distinct translated or same-title identities without writes" do
    payload = response(page: 2, total_pages: 3, total_results: 42, results: [
      { id: 20, title: "The Thing", original_title: "The Thing", original_language: "en", release_date: "1982-06-25", overview: "Unused" },
      { id: 10, title: "The Thing", original_title: "The Thing", release_date: "1982-06-25", poster_path: "Unused" },
      { id: 30, title: "Translated", original_title: "日本語", original_language: "ja", release_date: "" }
    ])
    result = assert_no_difference("Film.count") { search(payload, page: 2) }
    assert_equal({ page: 2, total_pages: 3, total_results: 42, candidates: [
      { tmdb_id: 20, title: "The Thing", original_title: "The Thing", release_date: Date.new(1982, 6, 25), original_language: "en" },
      { tmdb_id: 10, title: "The Thing", original_title: "The Thing", release_date: Date.new(1982, 6, 25), original_language: nil },
      { tmdb_id: 30, title: "Translated", original_title: "日本語", release_date: nil, original_language: "ja" }
    ] }, result)
    assert_equal 1, @http.requests.size
    assert_equal "/3/search/movie", URI(@http.requests.first.path).path
  end

  test "zero results and unknown dates are valid" do
    assert_equal({ page: 1, total_pages: 0, total_results: 0, candidates: [] }, search(response(total_pages: 0)))
    [ {}, { release_date: nil }, { release_date: "" }, { original_title: nil, original_language: nil } ].each do |attributes|
      candidate = search(response(results: [ { id: 1, title: "Unknown" }.merge(attributes) ]))[:candidates].first
      assert_nil candidate[:release_date]
      assert_nil candidate[:original_title]
      assert_nil candidate[:original_language]
    end
    date = search(response(results: [ { id: 1, title: "Leap", release_date: "2024-02-29" } ]))[:candidates].first[:release_date]
    assert_equal Date.new(2024, 2, 29), date
  end

  test "invalid input is rejected before any client or configuration access" do
    invalid = [ { query: nil }, { query: [] }, { query: " \t\n" }, { query: "x" * 201 },
      { page: nil }, { page: "1" }, { page: 1.0 }, { page: 0 }, { page: 501 },
      { primary_release_year: "1982" }, { primary_release_year: 999 }, { primary_release_year: 10000 },
      { primary_release_year: 1982.0 }, { query: "\xFF".b.force_encoding("UTF-8") } ]
    invalid.each do |attributes|
      assert_no_difference "Film.count" do
        assert_raises(FilmKnowledge::InvalidTmdbSearch) do
          FilmKnowledge::SearchTmdbFilms.call(**{ query: "Valid", client: Object.new }.merge(attributes))
        end
      end
    end
  end

  test "normalizes outer whitespace only and accepts explicit input boundaries" do
    calls = []
    client = Object.new
    client.define_singleton_method(:search) do |**options|
      calls << options
      { "page" => options[:page], "total_pages" => 0, "total_results" => 0, "results" => [] }
    end
    FilmKnowledge::SearchTmdbFilms.call(query: " \t日本語  & A?\n", page: 500, primary_release_year: 9999, client:)
    assert_equal({ query: "日本語  & A?", page: 500, primary_release_year: 9999 }, calls.last)
    FilmKnowledge::SearchTmdbFilms.call(query: "é" * 200, primary_release_year: 1000, client:)
    assert_equal 200, calls.last[:query].length
  end

  test "rejects malformed envelopes rather than returning partial data" do
    invalid = [ nil, [], "bad", {}, response.merge("results" => nil), response.merge("results" => {}),
      response.merge("page" => "1"), response.merge("page" => 2), response.merge("page" => nil),
      response.merge("total_pages" => -1), response.merge("total_results" => "0"),
      response.merge("total_pages" => nil), response.merge("total_results" => -1) ]
    invalid.each do |payload|
      assert_no_difference "Film.count" do
        assert_raises(FilmKnowledge::InvalidTmdbResponse) { search(payload) }
      end
    end
  end

  test "any malformed candidate rejects the whole page" do
    invalid = [ nil, [], "bad", { id: nil }, { id: 0 }, { id: -1 }, { id: "1" }, { id: 1.0 },
      { title: nil }, { title: " \t" }, { title: [] }, { original_title: 1 }, { original_language: false },
      { release_date: "1982" }, { release_date: "2023-02-29" }, { release_date: "1982-13-01" },
      { release_date: "1982-6-25" }, { release_date: "1982-06-25T00:00:00Z" }, { release_date: [] } ]
    invalid.each do |attributes|
      candidate = attributes.is_a?(Hash) ? { id: 1, title: "Bad" }.merge(attributes) : attributes
      payload = response(results: [ { id: 2, title: "Valid first" }, candidate ])
      assert_no_difference "Film.count" do
        assert_raises(FilmKnowledge::InvalidTmdbResponse) { search(payload) }
      end
    end
  end

  test "provider errors omit query credentials body and causes from logs and errors" do
    original_logger = Rails.logger
    output = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(output)
    { 401 => :authentication, 403 => :authentication, 429 => :rate_limited,
      404 => :http_error, 301 => :http_error, 500 => :http_error }.each do |code, reason|
      client = fake_http(code:, body: "private-body fake-test-token private-query")
      error = assert_no_difference "Film.count" do
        assert_raises(FilmKnowledge::TmdbUnavailable) do
          FilmKnowledge::SearchTmdbFilms.call(query: "private-query", client:)
        end
      end
      assert_equal reason, error.reason
      assert_nil error.cause
      [ "private-query", "private-body", "fake-test-token", "Authorization" ].each do |marker|
        refute_includes error.full_message, marker
        refute_includes output.string, marker
      end
      assert_equal 1, @http.requests.size
    end
  ensure
    Rails.logger = original_logger
  end
end
