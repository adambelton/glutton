require "test_helper"
require_relative "../../../support/film_import_sources"

class Registry::FetchWikipediaContextTest < ActiveSupport::TestCase
  include FilmImportSources

  def fetch(tmdb_id: 348, tmdb_client: tmdb_source, wikidata_client: wikidata_source, wikipedia_client: wikipedia_source)
    Registry::Sources::FetchWikipediaContext.call(tmdb_id:, tmdb_client:, wikidata_client:, wikipedia_client:)
  end

  test "resolves a revision without a persisted film or movie metadata request" do
    client = Object.new
    client.define_singleton_method(:external_ids) { |tmdb_id:| { "id" => tmdb_id, "wikidata_id" => "Q1" } }
    assert_no_difference "Registry::Film.count" do
      assert_equal wikipedia_context, fetch(tmdb_client: client)
    end
  end

  test "fetching again retrieves current context without replacing retained material" do
    film = Registry::Film.create!(title: "Alien", tmdb_id: 348, wikipedia_context: wikipedia_context)
    packet = wikipedia_context(text: "Fresh source paragraph.")
    source = Object.new
    source.define_singleton_method(:context) { |**| packet }
    assert_equal packet, fetch(wikipedia_client: source)
    assert_equal wikipedia_context, film.reload.wikipedia_context
  end

  test "missing identity is an explicit failure" do
    error = assert_raises(Registry::Errors::ImportIncomplete) { fetch(tmdb_id: nil, tmdb_client: Object.new) }
    assert_equal [ :tmdb, :missing_identity ], [ error.stage, error.reason ]
  end

  test "external identity provider errors include the selected identity without a film" do
    [ [ Registry::Errors::TmdbUnavailable.new(reason: :timeout), :timeout ],
      [ Registry::Errors::TmdbNotFound.new, :not_found ],
      [ Registry::Errors::TmdbConfigurationError.new, :configuration ],
      [ Registry::Errors::InvalidTmdbResponse.new, :invalid_response ] ].each do |failure, reason|
      client = Object.new
      client.define_singleton_method(:external_ids) { |**| raise failure }
      error = assert_raises(Registry::Errors::ImportIncomplete) { fetch(tmdb_client: client) }
      assert_equal [ :tmdb, reason, 348 ], [ error.stage, error.reason, error.tmdb_id ]
    end
  end
end
