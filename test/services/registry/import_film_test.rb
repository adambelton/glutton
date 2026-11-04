require "test_helper"
require_relative "../../support/tmdb_http"
require_relative "../../support/film_import_sources"

class Registry::ImportFilmTest < ActiveSupport::TestCase
  include TmdbHttp
  include FilmImportSources

  def import(payload)
    client = fake_http(body: JSON.generate(payload))
    client.define_singleton_method(:external_ids) { |tmdb_id:| { "id" => tmdb_id, "wikidata_id" => "Q1" } }
    Registry::ImportFilm.call(tmdb_id: 348, tmdb_client: client, wikidata_client: wikidata_source, wikipedia_client: wikipedia_source)
  end

  test "imports TMDB metadata and Wikipedia context ready for quality assessment" do
    freeze_time do
      payload = { id: 348, title: "Alien", original_title: "Alien", release_date: "1979-05-25",
        overview: "The crew encounters danger", poster_path: "Unused", credits: [ "Unused" ] }
      film = assert_difference("Registry::Film.count", 1) { import(payload) }
      assert film.persisted?
      assert film.has_source_context?
      assert_equal "Q1", film.wikidata_id
      assert_equal "Q1", film.wikipedia_context.dig("wikidata_id")
      assert_equal [ "Alien", 348, Date.new(1979, 5, 25) ], [ film.title, film.tmdb_id, film.release_date ]
      assert_equal "Alien", film.reload.tmdb_metadata["original_title"]
      assert_equal Time.current.utc.iso8601, film.tmdb_metadata.dig("fetched_at")
      assert_equal "The crew encounters danger", film.tmdb_metadata.dig("details", "overview")
      assert_nil film.tmdb_metadata.dig("details", "runtime")
      assert_not film.tmdb_metadata.dig("details").key?("credits")
    end
  end

  test "both sources are fetched before the only complete film insert" do
    client = tmdb_source
    client.define_singleton_method(:movie) do |tmdb_id:|
      raise "film persisted before metadata retrieval" if Registry::Film.exists?(tmdb_id:)
      { "id" => tmdb_id, "title" => "Alien" }
    end
    packet = wikipedia_context
    source = Object.new
    source.define_singleton_method(:context) do |tmdb_id:, **|
      raise "film persisted before Wikipedia retrieval" if Registry::Film.exists?(tmdb_id:)
      packet
    end
    insert_count = 0
    callback = lambda do |film|
      raise "initial insert lacks complete sources" unless film.has_source_context?
      insert_count += 1
    end
    Registry::Film.set_callback(:create, :before, callback)
    film = Registry::ImportFilm.call(tmdb_id: 348, tmdb_client: client, wikidata_client: wikidata_source, wikipedia_client: source)
    assert film.reload.has_source_context?
    assert_equal 1, insert_count
  ensure
    Registry::Film.skip_callback(:create, :before, callback, raise: false)
  end

  test "missing null or empty dates remain unknown and optional original title is omitted" do
    [ {}, { release_date: nil }, { release_date: "" } ].each do |attributes|
      film = import({ id: 348, title: "日本語 <film>" }.merge(attributes))
      assert_nil film.release_date
      assert_equal "日本語 <film>", film.title
      assert_not film.tmdb_metadata.key?("original_title")
      film.destroy!
    end
    assert_equal Date.new(2024, 2, 29), import({ id: 348, title: "Leap", release_date: "2024-02-29" }).release_date
  end

  test "existing films are explicit conflicts before provider calls" do
    [ { tmdb_metadata: {} }, { tmdb_metadata: { note: "Keep", details: {} } },
      { tmdb_metadata: { details: {} }, wikipedia_context: wikipedia_context } ].each do |attributes|
      film = Registry::Film.create!(tmdb_id: 348, title: "Local title", release_date: Date.new(1979, 5, 24), **attributes)
      timestamp = film.updated_at
      error = assert_raises(Registry::ImportIncomplete) do
        Registry::ImportFilm.call(tmdb_id: 348, tmdb_client: Object.new, wikidata_client: Object.new, wikipedia_client: Object.new)
      end
      assert_equal [ :persistence, :existing_film, 348 ], [ error.stage, error.reason, error.tmdb_id ]
      assert_equal "Local title", film.reload.title
      assert_equal Date.new(1979, 5, 24), film.release_date
      assert_equal timestamp, film.updated_at
      film.destroy!
    end
  end

  test "invalid optional TMDB metadata is rejected atomically" do
    [ { overview: [] }, { runtime: -1 }, { runtime: "117" }, { genres: "Horror" },
      { genres: [ { id: "27", name: "Horror" } ] }, { production_countries: [ "US" ] } ].each do |changes|
      assert_no_difference "Registry::Film.count" do
        assert_raises(Registry::ImportIncomplete) { import({ id: 348, title: "Alien" }.merge(changes)) }
      end
    end
  end

  test "invalid responses never write" do
    invalid = [ { id: "348" }, { id: 349 }, { id: nil }, { title: nil }, { title: " \t" }, { title: 9 },
      { original_title: [] }, { release_date: [] }, { release_date: 1979 }, { release_date: "1979" },
      { release_date: "2023-02-29" }, { release_date: "1979-13-01" }, { release_date: "1979-5-25" },
      { release_date: "1979-05-25T00:00:00Z" } ]
    invalid.each do |attributes|
      assert_no_difference "Registry::Film.count" do
        assert_raises(Registry::ImportIncomplete) { import({ id: 348, title: "Alien" }.merge(attributes)) }
      end
    end
    [ [], nil, "bad", 10 ].each do |payload|
      assert_no_difference "Registry::Film.count" do
        assert_raises(Registry::ImportIncomplete) { import(payload) }
      end
    end
  end

  test "invalid IDs and provider failures leave no records and emit no private logs" do
    output = StringIO.new
    logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output)
    [ nil, 0, -1, 1.0, "348" ].each do |id|
      assert_no_difference "Registry::Film.count" do
        assert_raises(Registry::InvalidTmdbId) { Registry::ImportFilm.call(tmdb_id: id, tmdb_client: Object.new) }
      end
    end
    [ 401, 403, 404, 429, 302, 500 ].each do |code|
      client = fake_http(code:, body: "private-body fake-test-token")
      assert_no_difference "Registry::Film.count" do
        assert_raises(Registry::ImportIncomplete) do
          Registry::ImportFilm.call(tmdb_id: 348, tmdb_client: client)
        end
      end
    end
    refute_includes output.string, "private-body"
    refute_includes output.string, "fake-test-token"
  ensure
    Rails.logger = logger
  end

  test "a persistence failure rolls back and can be explicitly retried" do
    callback = -> { raise ActiveRecord::StatementInvalid, "injected persistence failure" }
    Registry::Film.set_callback(:create, :after, callback)
    assert_no_difference "Registry::Film.count" do
      assert_raises(ActiveRecord::StatementInvalid) { import({ id: 348, title: "Alien" }) }
    end
    Registry::Film.skip_callback(:create, :after, callback)
    assert_difference("Registry::Film.count", 1) { import({ id: 348, title: "Alien" }) }
  ensure
    Registry::Film.skip_callback(:create, :after, callback, raise: false)
  end

  test "an unrelated unique constraint failure is not mistaken for the identity race" do
    existing = Registry::Film.create!(title: "Existing without TMDB identity")
    # Inject a real unrelated database constraint failure without mutating the import's model.
    callback = -> { Registry::Film.insert_all!([ { id: existing.id, title: "Injected primary-key conflict" } ]) }
    Registry::Film.set_callback(:create, :before, callback)
    assert_no_difference "Registry::Film.count" do
      assert_raises(ActiveRecord::RecordNotUnique) { import({ id: 348, title: "Alien" }) }
    end
    assert_not Registry::Film.exists?(tmdb_id: 348)
  ensure
    Registry::Film.skip_callback(:create, :before, callback, raise: false)
  end

  test "same title and date never merge different or unlinked identities" do
    local = Registry::Film.create!(title: "Alien", release_date: Date.new(1979, 5, 25))
    imported = import({ id: 348, title: "Alien", release_date: "1979-05-25" })
    other = Registry::ImportFilm.call(tmdb_id: 349, tmdb_client: tmdb_source(payload: { "id" => 349, "title" => "Alien", "release_date" => "1979-05-25" }), wikidata_client: wikidata_source, wikipedia_client: wikipedia_source)
    assert_equal 3, [ local.id, imported.id, other.id ].uniq.size
  end
end
