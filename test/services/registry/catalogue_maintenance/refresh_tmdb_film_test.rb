require "test_helper"
require_relative "../../../support/film_import_sources"

class Registry::RefreshTmdbFilmTest < ActiveSupport::TestCase
  include FilmImportSources

  setup do
    @film = Registry::Film.create!(title: "Previous title", tmdb_id: 348, release_date: Date.new(1979, 5, 24),
      wikidata_id: "Q1", wikipedia_context: wikipedia_context,
      tmdb_metadata: { details: { overview: "Previous", poster_path: "/old.jpg" } })
  end

  test "refresh replaces the complete packet while preserving identity and accepted knowledge" do
    quality = Registry::Quality.create!(name: "Atmospheric", quality_category: quality_categories(:tone),
      match_rule: "Sustained atmosphere", not_sufficient: "One moment")
    association = Registry::FilmQuality.create!(film: @film, quality:)
    payload = { "id" => 348, "title" => "Alien", "release_date" => "1979-05-25", "vote_count" => 1000,
      "popularity" => 12.5, "future" => { "values" => [ false, nil, "" ] } }
    assert_no_difference [ "Registry::Film.count", "Registry::FilmQuality.count", "Registry::FilmQualityEval.count", "DomainEvents::DomainEvent.count" ] do
      refreshed = Registry::CatalogueMaintenance::RefreshTmdbFilm.call(film_id: @film.id, tmdb_client: tmdb_source(payload:))
      assert_equal @film.id, refreshed.id
    end
    @film.reload
    assert_equal "Alien", @film.title
    assert_equal Date.new(1979, 5, 25), @film.release_date
    assert_equal payload, @film.tmdb_metadata.fetch("details")
    assert_nil @film.tmdb_details.poster_path
    assert_equal 1000, @film.tmdb_details.vote_count
    assert_equal wikipedia_context, @film.wikipedia_context
    assert_equal "Q1", @film.wikidata_id
    assert_equal [ association.id ], @film.film_qualities.pluck(:id)
  end

  test "invalid provider response leaves the previous source and title unchanged" do
    timestamp = @film.updated_at
    [ { "id" => 349, "title" => "Wrong" }, { "id" => 348, "title" => "" },
      { "id" => 348, "title" => "Alien", "release_date" => "bad" } ].each do |payload|
      assert_raises(Registry::Errors::ImportIncomplete) do
        Registry::CatalogueMaintenance::RefreshTmdbFilm.call(film_id: @film.id, tmdb_client: tmdb_source(payload:))
      end
      assert_equal "Previous title", @film.reload.title
      assert_equal "/old.jpg", @film.tmdb_details.poster_path
      assert_equal timestamp, @film.updated_at
    end
  end

  test "missing films do not call the provider and deleted films cannot be refreshed" do
    id = @film.id
    @film.destroy!
    assert_raises(ActiveRecord::RecordNotFound) { Registry::CatalogueMaintenance::RefreshTmdbFilm.call(film_id: id, tmdb_client: Object.new) }
    film = Registry::Film.create!(title: "Original", tmdb_id: 348)
    client = Object.new
    client.define_singleton_method(:movie) do |tmdb_id:|
      film.destroy!
      { "id" => tmdb_id, "title" => "Fetched" }
    end
    assert_raises(ActiveRecord::RecordNotFound) { Registry::CatalogueMaintenance::RefreshTmdbFilm.call(film_id: film.id, tmdb_client: client) }
    assert_not Registry::Film.exists?(film.id)
  end

  test "a different identity occupying the same ID after retrieval is not overwritten" do
    film = @film
    client = Object.new
    client.define_singleton_method(:movie) do |tmdb_id:|
      film.destroy!
      Registry::Film.create!(id: film.id, title: "Replacement identity", tmdb_id: 349)
      { "id" => tmdb_id, "title" => "Fetched" }
    end
    assert_raises(Registry::Errors::InvalidTmdbId) { Registry::CatalogueMaintenance::RefreshTmdbFilm.call(film_id: film.id, tmdb_client: client) }
    assert_equal "Replacement identity", Registry::Film.find(film.id).title
  end
end
