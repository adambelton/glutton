require "test_helper"
require_relative "../support/film_import_sources"

class FilmQualityTest < ActiveSupport::TestCase
  include FilmImportSources

  setup do
    @film = Film.new(tmdb_id: 348)
    @film.import!(tmdb_data: { title: "Sourced film", release_date: nil, tmdb_metadata: { details: { overview: "Metadata" } } },
      wikipedia_context: wikipedia_context)
    @quality = Quality.create!(name: "Sustained dread", quality_category: quality_categories(:tone))
  end

  test "current qualities and source references survive a rejected reimport" do
    film_quality = @film.film_qualities.create!(quality: @quality, evidence_references: [ "P1" ])
    assert_equal [ @quality ], @film.reload.qualities.to_a
    assert_equal [ @film ], @quality.films.to_a
    error = assert_raises(FilmKnowledge::ImportIncomplete) { @film.import!(tmdb_data: {}, wikipedia_context: {}) }
    assert_equal :existing_film, error.reason
    assert_equal @quality, @film.reload.qualities.sole
    assert_equal [ "P1" ], film_quality.reload.evidence_references
    assert_equal "Metadata", @film.tmdb_metadata.dig("details", "overview")
  end

  test "invalid evidence duplicate associations and dangling identities are rejected" do
    [ nil, [], {}, "P1", [ "" ], [ 123 ] ].each do |evidence|
      film_quality = @film.film_qualities.new(quality: @quality, evidence_references: evidence)
      assert_not film_quality.valid?
      assert film_quality.errors.of_kind?(:evidence_references, :invalid)
      assert film_quality.errors.full_messages.none? { |message| message.include?("Translation missing") }
    end
    @film.film_qualities.create!(quality: @quality, evidence_references: [ "P1" ])
    assert_raises(ActiveRecord::RecordNotUnique) do
      FilmQuality.transaction(requires_new: true) do
        @film.film_qualities.create!(quality: @quality, evidence_references: [ "P1" ])
      end
    end
    [ { film_id: -1, quality_id: @quality.id, evidence_references: [ "P1" ] },
      { film_id: @film.id, quality_id: -1, evidence_references: [ "P1" ] },
      { film_id: @film.id, quality_id: @quality.id, evidence_references: [] } ].each do |attributes|
      assert_raises(ActiveRecord::StatementInvalid) do
        FilmQuality.transaction(requires_new: true) { FilmQuality.insert_all!([ attributes ]) }
      end
    end
  end

  test "film and quality deletion cannot orphan accepted evidence" do
    @film.film_qualities.create!(quality: @quality, evidence_references: [ "P1" ])
    assert_raises(ActiveRecord::DeleteRestrictionError) { @film.destroy! }
    assert_raises(ActiveRecord::DeleteRestrictionError) { @quality.destroy! }
  end

  test "Wikipedia context validates constructor input and database storage" do
    [ nil, [], "text" ].each do |context|
      film = Film.new(title: "Invalid source", wikipedia_context: context)
      assert_not film.valid?
      assert film.errors.of_kind?(:wikipedia_context, :invalid)
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      # Deliberately bypass the model to verify the database's JSON-object constraint.
      Film.transaction(requires_new: true) { Film.insert_all!([ { title: "Bypass", wikipedia_context: [] } ]) }
    end
  end
end
