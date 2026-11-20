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
      assert_equal wikipedia_context, fetch(tmdb_client: client).wikipedia_context
    end
  end

  test "fetching again retrieves current context without replacing retained material" do
    film = Registry::Film.create!(title: "Alien", tmdb_id: 348, wikipedia_context: wikipedia_context)
    packet = wikipedia_context(text: "Fresh source paragraph.")
    source = Object.new
    source.define_singleton_method(:context) { |**| packet }
    assert_equal packet, fetch(wikipedia_client: source).wikipedia_context
    assert_equal wikipedia_context, film.reload.wikipedia_context
  end

  test "missing identity ends enrichment" do
    result = fetch(tmdb_id: nil, tmdb_client: Object.new)
    assert_nil result.wikidata_id
    assert_empty result.wikipedia_context
  end

  test "external identity provider errors end enrichment" do
    [ Registry::Errors::TmdbUnavailable.new(reason: :timeout), Registry::Errors::TmdbNotFound.new,
      Registry::Errors::TmdbConfigurationError.new, Registry::Errors::InvalidTmdbResponse.new ].each do |failure|
      client = Object.new
      client.define_singleton_method(:external_ids) { |**| raise failure }
      result = fetch(tmdb_client: client)
      assert_nil result.wikidata_id
      assert_empty result.wikipedia_context
    end
  end
end
