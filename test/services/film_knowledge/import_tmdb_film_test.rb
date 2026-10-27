require "test_helper"
require_relative "../../support/tmdb_http"

class FilmKnowledge::ImportTmdbFilmTest < ActiveSupport::TestCase
  include TmdbHttp

  def import(payload)
    client = fake_http(body: JSON.generate(payload))
    FilmKnowledge::ImportTmdbFilm.call(tmdb_id: 348, client:)
  end

  test "maps identity analysis metadata and source provenance" do
    freeze_time do
      payload = { id: 348, title: "Alien", original_title: "Alien", release_date: "1979-05-25",
        overview: "The crew encounters danger", poster_path: "Unused", credits: [ "Unused" ] }
      film = assert_difference("Film.count", 1) { import(payload) }
      assert film.persisted?
      assert_equal [ "Alien", 348, Date.new(1979, 5, 25) ], [ film.title, film.tmdb_id, film.release_date ]
      assert_equal "Alien", film.reload.metadata["original_title"]
      assert_equal Time.current.utc.iso8601, film.metadata.dig("tmdb", "fetched_at")
      assert_equal "The crew encounters danger", film.metadata.dig("tmdb", "details", "overview")
      assert_nil film.metadata.dig("tmdb", "details", "runtime")
      assert_not film.metadata.dig("tmdb", "details").key?("credits")
    end
  end

  test "missing null or empty dates remain unknown and optional original title is omitted" do
    [ {}, { release_date: nil }, { release_date: "" } ].each do |attributes|
      film = import({ id: 348, title: "日本語 <film>" }.merge(attributes))
      assert_nil film.release_date
      assert_equal "日本語 <film>", film.title
      assert_not film.metadata.key?("original_title")
      film.destroy!
    end
    assert_equal Date.new(2024, 2, 29), import({ id: 348, title: "Leap", release_date: "2024-02-29" }).release_date
  end

  test "generation refreshes legacy imports once through movie details and preserves local fields" do
    film = Film.create!(title: "Local title", tmdb_id: 348, metadata: { note: "Keep" })
    payload = { id: 348, title: "Alien", overview: "Crew in danger", tagline: "In space", runtime: 117,
      original_language: "en", status: "Released", budget: 11000000, revenue: 100000000,
      genres: [ { id: 27, name: "Horror" } ], production_companies: [ { id: 1, name: "Studio", origin_country: "US" } ],
      production_countries: [ { iso_3166_1: "US", name: "United States" } ],
      spoken_languages: [ { iso_639_1: "en", name: "English", english_name: "English" } ] }
    client = fake_http(body: payload.to_json)
    assert_no_difference "Film.count" do
      assert_equal film, FilmKnowledge::ImportTmdbFilm.call(tmdb_id: 348, client:, ensure_metadata: true)
    end
    assert_equal "Local title", film.reload.title
    assert_equal "Keep", film.metadata["note"]
    assert_equal 117, film.metadata.dig("tmdb", "details", "runtime")
    assert_equal [ { "id" => 27, "name" => "Horror" } ], film.metadata.dig("tmdb", "details", "genres")
    assert_equal "US", film.metadata.dig("tmdb", "details", "production_companies", 0, "origin_country")
    assert_equal film, FilmKnowledge::ImportTmdbFilm.call(tmdb_id: 348, client: Object.new, ensure_metadata: true)
  end

  test "invalid optional metadata is rejected atomically" do
    [ { overview: [] }, { runtime: -1 }, { runtime: "117" }, { genres: "Horror" },
      { genres: [ { id: "27", name: "Horror" } ] }, { production_countries: [ "US" ] } ].each do |changes|
      assert_no_difference "Film.count" do
        assert_raises(FilmKnowledge::InvalidTmdbResponse) { import({ id: 348, title: "Alien" }.merge(changes)) }
      end
    end
  end

  test "invalid responses never write" do
    invalid = [ { id: "348" }, { id: 349 }, { id: nil }, { title: nil }, { title: " \t" }, { title: 9 },
      { original_title: [] }, { release_date: [] }, { release_date: 1979 }, { release_date: "1979" },
      { release_date: "2023-02-29" }, { release_date: "1979-13-01" }, { release_date: "1979-5-25" },
      { release_date: "1979-05-25T00:00:00Z" } ]
    invalid.each do |attributes|
      assert_no_difference "Film.count" do
        assert_raises(FilmKnowledge::InvalidTmdbResponse) { import({ id: 348, title: "Alien" }.merge(attributes)) }
      end
    end
    [ [], nil, "bad", 10 ].each do |payload|
      assert_no_difference "Film.count" do
        assert_raises(FilmKnowledge::InvalidTmdbResponse) { import(payload) }
      end
    end
  end

  test "existing films bypass client and configuration and retain all local metadata" do
    existing = Film.create!(tmdb_id: 348, title: "Edited", release_date: Date.new(1979, 5, 24), metadata: { note: "Keep" })
    updated_at = existing.updated_at
    assert_no_difference "Film.count" do
      assert_equal existing, FilmKnowledge::ImportTmdbFilm.call(tmdb_id: 348, client: Object.new)
      assert_equal existing, FilmKnowledge::ImportTmdbFilm.call(tmdb_id: 348)
    end
    existing.reload
    assert_equal "Edited", existing.title
    assert_equal Date.new(1979, 5, 24), existing.release_date
    assert_equal({ "note" => "Keep" }, existing.metadata)
    assert_equal updated_at, existing.updated_at
  end

  test "invalid IDs and provider failures leave no records and emit no private logs" do
    output = StringIO.new
    logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output)
    [ nil, 0, -1, 1.0, "348" ].each do |id|
      assert_no_difference "Film.count" do
        assert_raises(FilmKnowledge::InvalidTmdbId) { FilmKnowledge::ImportTmdbFilm.call(tmdb_id: id, client: Object.new) }
      end
    end
    [ 401, 403, 404, 429, 302, 500 ].each do |code|
      client = fake_http(code:, body: "private-body fake-test-token")
      assert_no_difference "Film.count" do
        assert_raises(FilmKnowledge::TmdbNotFound, FilmKnowledge::TmdbUnavailable) do
          FilmKnowledge::ImportTmdbFilm.call(tmdb_id: 348, client:)
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
    Film.set_callback(:create, :after, callback)
    assert_no_difference "Film.count" do
      assert_raises(ActiveRecord::StatementInvalid) { import({ id: 348, title: "Alien" }) }
    end
    Film.skip_callback(:create, :after, callback)
    assert_difference("Film.count", 1) { import({ id: 348, title: "Alien" }) }
  ensure
    Film.skip_callback(:create, :after, callback, raise: false)
  end

  test "an unrelated unique constraint failure is not mistaken for the identity race" do
    existing = Film.create!(title: "Existing without TMDB identity")
    callback = ->(film) { film.id = existing.id }
    Film.set_callback(:create, :before, callback)
    assert_no_difference "Film.count" do
      assert_raises(ActiveRecord::RecordNotUnique) { import({ id: 348, title: "Alien" }) }
    end
    assert_not Film.exists?(tmdb_id: 348)
  ensure
    Film.skip_callback(:create, :before, callback, raise: false)
  end

  test "same title and date never merge different or unlinked identities" do
    local = Film.create!(title: "Alien", release_date: Date.new(1979, 5, 25))
    imported = import({ id: 348, title: "Alien", release_date: "1979-05-25" })
    client = fake_http(body: '{"id":349,"title":"Alien","release_date":"1979-05-25"}')
    other = FilmKnowledge::ImportTmdbFilm.call(tmdb_id: 349, client:)
    assert_equal 3, [ local.id, imported.id, other.id ].uniq.size
  end
end
