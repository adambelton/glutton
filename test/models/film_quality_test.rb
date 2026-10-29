require "test_helper"

class FilmQualityTest < ActiveSupport::TestCase
  setup do
    @film = Film.create!(title: "Sourced film", metadata: { tmdb: { details: { overview: "Metadata" } } },
      source_context: { page_id: 123, revision_id: 456, source_paragraphs: [ { id: "P1", text: "Supported context" } ] })
    @quality = Quality.create!(name: "Sustained dread", quality_category: quality_categories(:tone))
  end

  test "current qualities are associated directly with films and retain source references" do
    film_quality = @film.film_qualities.create!(quality: @quality, evidence_references: [ "P1" ])
    assert_equal [ @quality ], @film.reload.qualities.to_a
    assert_equal [ @film ], @quality.films.to_a
    assert_equal [ "P1" ], film_quality.reload.evidence_references
    @film.update!(source_context: @film.source_context.merge("revision_id" => 457))
    assert_equal @quality, @film.reload.qualities.sole
    assert_equal [ "P1" ], film_quality.reload.evidence_references
    assert_equal "Metadata", @film.metadata.dig("tmdb", "details", "overview")
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

  test "source context must remain an independent object in models and storage" do
    other = Film.new(title: "Other")
    other.source_context["page_id"] = 789
    assert_equal({}, Film.new(title: "Empty").source_context)
    [ nil, [], "text" ].each do |context|
      @film.source_context = context
      assert_not @film.valid?
      assert @film.errors.of_kind?(:source_context, :invalid)
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Film.transaction(requires_new: true) { @film.reload.update_columns(source_context: []) }
    end
  end
end
