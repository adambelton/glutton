require "test_helper"
require_relative "../../support/film_import_sources"

class Registry::FetchTmdbFilmTest < ActiveSupport::TestCase
  include FilmImportSources

  test "fetches fresh TMDB metadata without a Film or Wikipedia request" do
    client = Object.new
    client.define_singleton_method(:movie) { |tmdb_id:| { "id" => tmdb_id, "title" => "Alien", "overview" => "A crew encounters a threat." } }
    assert_no_difference "Registry::Film.count" do
      data = Registry::FetchTmdbFilm.call(tmdb_id: 348, tmdb_client: client)
      assert_equal "Alien", data.fetch(:title)
      assert_equal "A crew encounters a threat.", data.dig(:tmdb_metadata, "details", "overview")
      assert_nil data.fetch(:release_date)
    end
  end

  test "fetching again retrieves current data without changing an existing film" do
    film = Registry::Film.create!(title: "Local title", tmdb_id: 348, tmdb_metadata: { note: "Keep" })
    first = Registry::FetchTmdbFilm.call(tmdb_id: 348, tmdb_client: tmdb_source)
    second = Registry::FetchTmdbFilm.call(tmdb_id: 348, tmdb_client: tmdb_source(payload: { "id" => 348, "title" => "Updated" }))
    assert_equal "Alien", first.fetch(:title)
    assert_equal "Updated", second.fetch(:title)
    assert_equal "Local title", film.reload.title
    assert_equal({ "note" => "Keep" }, film.tmdb_metadata)
  end
  test "optional metadata is retained without interpretation or mutation of the response" do
    payload = { "id" => 348, "title" => "Alien", "poster_path" => 123, "unknown" => { "values" => [ nil, false, "" ] } }
    data = Registry::FetchTmdbFilm.call(tmdb_id: 348, tmdb_client: tmdb_source(payload:))
    assert_equal payload, data.dig(:tmdb_metadata, "details")
    assert_nil Registry::TmdbMetadata.new(data.fetch(:tmdb_metadata)).poster_path
    data.dig(:tmdb_metadata, "details", "unknown", "values") << "copy"
    assert_equal [ nil, false, "" ], payload.dig("unknown", "values")
  end
end
