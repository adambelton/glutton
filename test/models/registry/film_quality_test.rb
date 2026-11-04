require "test_helper"
require_relative "../../support/film_import_sources"

class Registry::FilmQualityTest < ActiveSupport::TestCase
  include FilmImportSources

  setup do
    @film = Registry::Film.new(tmdb_id: 348)
    @film.import!(tmdb_data: { title: "Sourced film", release_date: nil, tmdb_metadata: { details: { overview: "Metadata" } } },
      wikipedia_context: wikipedia_context)
    @quality = Registry::Quality.create!(name: "Sustained dread", quality_category: quality_categories(:tone))
  end

  test "current qualities survive a rejected reimport" do
    @film.film_qualities.create!(quality: @quality)
    assert_equal [ @quality ], @film.reload.qualities.to_a
    assert_equal [ @film ], @quality.films.to_a
    error = assert_raises(Registry::ImportIncomplete) { @film.import!(tmdb_data: {}, wikipedia_context: {}) }
    assert_equal :existing_film, error.reason
    assert_equal @quality, @film.reload.qualities.sole
    assert_equal "Metadata", @film.tmdb_metadata.dig("details", "overview")
  end

  test "duplicate associations and dangling identities are rejected" do
    @film.film_qualities.create!(quality: @quality)
    assert_raises(ActiveRecord::RecordNotUnique) do
      Registry::FilmQuality.transaction(requires_new: true) do
        @film.film_qualities.create!(quality: @quality)
      end
    end
    [ { film_id: -1, quality_id: @quality.id },
      { film_id: @film.id, quality_id: -1 } ].each do |attributes|
      assert_raises(ActiveRecord::StatementInvalid) do
        Registry::FilmQuality.transaction(requires_new: true) { Registry::FilmQuality.insert_all!([ attributes ]) }
      end
    end
  end

  test "film and quality deletion cannot orphan accepted associations" do
    @film.film_qualities.create!(quality: @quality)
    assert_raises(ActiveRecord::DeleteRestrictionError) { @film.destroy! }
    assert_raises(ActiveRecord::DeleteRestrictionError) { @quality.destroy! }
  end

  test "Wikipedia context validates constructor input and database storage" do
    [ nil, [], "text" ].each do |context|
      film = Registry::Film.new(title: "Invalid source", wikipedia_context: context)
      assert_not film.valid?
      assert film.errors.of_kind?(:wikipedia_context, :invalid)
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      # Deliberately bypass the model to verify the database's JSON-object constraint.
      Registry::Film.transaction(requires_new: true) { Registry::Film.insert_all!([ { title: "Bypass", wikipedia_context: [] } ]) }
    end
  end
end
