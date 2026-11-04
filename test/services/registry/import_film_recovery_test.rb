require "test_helper"
require_relative "../../support/film_import_sources"

class Registry::ImportFilmRecoveryTest < ActiveSupport::TestCase
  include FilmImportSources

  def run_import(tmdb_client: tmdb_source, wikidata_client: wikidata_source, wikipedia_client: wikipedia_source)
    Registry::ImportFilm.call(tmdb_id: 348, tmdb_client:, wikidata_client:, wikipedia_client:)
  end

  test "source failure creates no film and retry fetches both inputs" do
    source = Object.new
    source.define_singleton_method(:context) { |**| raise Registry::ImportIncomplete.new(stage: :wikipedia, reason: :timeout) }
    assert_no_difference "Registry::Film.count" do
      error = assert_raises(Registry::ImportIncomplete) { run_import(wikipedia_client: source) }
      assert_equal [ :wikipedia, :timeout, 348 ], [ error.stage, error.reason, error.tmdb_id ]
    end
    assert_not Registry::Film.exists?(tmdb_id: 348)
    assert_difference "Registry::Film.count", 1 do
      assert run_import.has_source_context?
    end
  end

  test "missing or mismatched external identity creates no film" do
    [ nil, {}, { "id" => 349, "wikidata_id" => "Q1" }, { "id" => 348 }, { "id" => 348, "wikidata_id" => "Q0" } ].each do |external_ids|
      client = tmdb_source
      client.define_singleton_method(:external_ids) { |**| external_ids }
      error = assert_raises(Registry::ImportIncomplete) { run_import(tmdb_client: client) }
      assert_equal :tmdb, error.stage
      assert_includes [ :invalid_response, :missing_identity ], error.reason
      assert_not Registry::Film.exists?(tmdb_id: 348)
    end
  end

  test "invalid packets cannot create a film" do
    source = Object.new
    source.define_singleton_method(:context) { |**| { "source_paragraphs" => [] } }
    error = assert_raises(Registry::ImportIncomplete) { run_import(wikipedia_client: source) }
    assert_equal [ :wikipedia, :invalid_response ], [ error.stage, error.reason ]
    assert_not Registry::Film.exists?(tmdb_id: 348)
  end

  test "existing incomplete context needs review and is never overwritten" do
    film = Registry::Film.create!(tmdb_id: 348, title: "Edited", tmdb_metadata: { details: {} }, wikipedia_context: { note: "Keep correction" })
    error = assert_raises(Registry::ImportIncomplete) { run_import }
    assert_equal [ :persistence, :existing_film ], [ error.stage, error.reason ]
    assert_equal({ "note" => "Keep correction" }, film.reload.wikipedia_context)
  end

  test "import does not change accepted qualities or other domains" do
    film = Registry::Film.create!(tmdb_id: 349, title: "Other film", tmdb_metadata: { details: {} })
    category = Registry::QualityCategory.create!(name: "Import test", maximum_qualities: 2)
    quality = Registry::Quality.create!(name: "Existing quality", quality_category: category)
    association = Registry::FilmQuality.create!(film:, quality:)
    timestamp = association.updated_at
    assert_no_difference [ "Registry::FilmQuality.count", "Library::LibraryFilm.count", "Rating.count", "DomainEvent.count" ] do
      assert run_import.has_source_context?
    end
    assert_equal timestamp, association.updated_at
  end

  test "all import stage and reason messages have English translations" do
    translations = I18n.t("registry.import", locale: :en)
    translations.fetch(:stages).each_key do |stage|
      translations.fetch(:reasons).each_key do |reason|
        error = Registry::ImportIncomplete.new(stage:, reason:)
        refute_match(/translation missing/i, error.message)
      end
    end
  end
end
