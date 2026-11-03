require "test_helper"
require_relative "../../support/film_import_sources"

class FilmKnowledge::FetchTmdbFilmTest < ActiveSupport::TestCase
  include FilmImportSources

  test "fetches fresh TMDB metadata without a Film or Wikipedia request" do
    client = Object.new
    client.define_singleton_method(:movie) { |tmdb_id:| { "id" => tmdb_id, "title" => "Alien", "overview" => "A crew encounters a threat." } }
    assert_no_difference "Film.count" do
      data = FilmKnowledge::FetchTmdbFilm.call(tmdb_id: 348, tmdb_client: client)
      assert_equal "Alien", data.fetch(:title)
      assert_equal "A crew encounters a threat.", data.dig(:tmdb_metadata, "details", "overview")
      assert_nil data.fetch(:release_date)
    end
  end

  test "fetching again retrieves current data without changing an existing film" do
    film = Film.create!(title: "Local title", tmdb_id: 348, tmdb_metadata: { note: "Keep" })
    first = FilmKnowledge::FetchTmdbFilm.call(tmdb_id: 348, tmdb_client: tmdb_source)
    second = FilmKnowledge::FetchTmdbFilm.call(tmdb_id: 348, tmdb_client: tmdb_source(payload: { "id" => 348, "title" => "Updated" }))
    assert_equal "Alien", first.fetch(:title)
    assert_equal "Updated", second.fetch(:title)
    assert_equal "Local title", film.reload.title
    assert_equal({ "note" => "Keep" }, film.tmdb_metadata)
  end
end
