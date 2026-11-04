require "test_helper"
require_relative "../../support/film_import_sources"

class Registry::FilmTest < ActiveSupport::TestCase
  include FilmImportSources

  test "import supplies matching article identity and ready source inputs" do
    film = Registry::Film.new(tmdb_id: 348)
    assert_not film.has_source_context?
    film.import!(tmdb_data: { title: "Alien", release_date: nil, tmdb_metadata: { "details" => {} } }, wikipedia_context: wikipedia_context)
    assert film.reload.has_source_context?
    assert_equal "Q1", film.wikidata_id
    assert_equal wikipedia_context, film.wikipedia_context
  end

  test "import rejects invalid provenance and narrative through its input arguments" do
    [ nil, {}, wikipedia_context.merge("tmdb_id" => 349), wikipedia_context.except("license"), wikipedia_context.except("language"), wikipedia_context.merge("language" => "fr"),
      wikipedia_context.merge("revision_url" => "https://en.wikipedia.org/w/index.php?oldid=99"),
      wikipedia_context.merge("source_paragraphs" => []),
      wikipedia_context.merge("source_paragraphs" => [ { "id" => "P1", "section" => "Reception", "text" => "Critics praised the film." } ]) ].each do |context|
      film = Registry::Film.new(tmdb_id: 348)
      assert_no_difference "Registry::Film.count" do
        error = assert_raises(Registry::ImportIncomplete) do
          film.import!(tmdb_data: { title: "Alien", release_date: nil, tmdb_metadata: { "details" => {} } }, wikipedia_context: context)
        end
        assert_equal [ :wikipedia, :invalid_response ], [ error.stage, error.reason ]
      end
    end
  end

  test "readiness rejects constructor state with mismatched article identity" do
    film = Registry::Film.new(title: "Mismatched source", tmdb_id: 348, wikidata_id: "Q2",
      tmdb_metadata: { details: {} }, wikipedia_context: wikipedia_context)
    assert_not film.has_source_context?
  end

  test "provider content can be empty while identifiers remain available" do
    film = Registry::Film.create!(title: "Purged content", tmdb_id: 348, wikidata_id: "Q1")
    assert_equal({}, film.tmdb_metadata)
    assert_equal({}, film.wikipedia_context)
    assert_equal film.id, Registry::Film.find_by!(wikidata_id: "Q1").id
    assert_equal 348, film.tmdb_id
    assert_not film.has_source_context?
  end

  test "Wikidata identifier is nullable and uses the Q identifier format" do
    assert Registry::Film.new(title: "Unlinked").valid?
    [ "Q0", "Q-1", "bad", "Q1.5", "Q01", "Q1\n" ].each do |identifier|
      film = Registry::Film.new(title: "Invalid", wikidata_id: identifier)
      assert_not film.valid?
      assert film.errors[:wikidata_id].any?
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Registry::Film.transaction(requires_new: true) do
        Registry::Film.insert_all!([ { title: "Bypass", wikidata_id: "Q0" } ])
      end
    end
    I18n.with_locale(:en) do
      film = Registry::Film.new(title: "Invalid", wikidata_id: "Q-1")
      film.valid?
      assert_includes film.errors.full_messages, "Wikidata ID is invalid"
    end
  end

  test "import refuses to change a persisted film" do
    film = Registry::Film.create!(title: "Local title", tmdb_id: 348, tmdb_metadata: { note: "Keep" }, wikipedia_context: { note: "Keep source" })
    timestamp = film.updated_at
    error = assert_raises(Registry::ImportIncomplete) do
      film.import!(tmdb_data: {}, wikipedia_context: wikipedia_context)
    end
    assert_equal [ :persistence, :existing_film ], [ error.stage, error.reason ]
    assert_equal "Local title", film.reload.title
    assert_equal({ "note" => "Keep" }, film.tmdb_metadata)
    assert_equal({ "note" => "Keep source" }, film.wikipedia_context)
    assert_equal timestamp, film.updated_at
  end

  test "invalid context cannot create a partially imported film" do
    film = Registry::Film.new(tmdb_id: 348)
    assert_no_difference "Registry::Film.count" do
      assert_raises(Registry::ImportIncomplete) do
        film.import!(tmdb_data: { title: "Alien", release_date: nil, tmdb_metadata: {} }, wikipedia_context: {})
      end
    end
  end

  test "minimal and complete metadata retain their own identities" do
    minimal = Registry::Film.create!(title: "A film")
    assert_equal "A film", minimal.reload.title
    assert_equal({}, minimal.tmdb_metadata)
    assert_nil minimal.release_date
    assert_nil minimal.tmdb_id

    attributes = { title: "A film", tmdb_metadata: { "original_title" => "Original title" }, release_date: Date.new(1982, 6, 25), tmdb_id: 1091 }
    complete = Registry::Film.create!(attributes)
    assert_equal attributes.stringify_keys, complete.reload.slice(*attributes.keys.map(&:to_s))
    assert_not_equal minimal.id, complete.id
    another = Registry::Film.create!(attributes.merge(tmdb_id: 999))
    assert_not_equal complete.id, another.id
    assert_equal complete.release_date, another.release_date
  end

  test "title is required and metadata remains unmodified" do
    [ nil, "", " \t" ].each do |title|
      film = Registry::Film.new(title: title)
      assert_not film.valid?
      assert film.errors.of_kind?(:title, :blank)
    end
    film = Registry::Film.create!(title: "日本語 <title>", tmdb_metadata: { original_title: " Original " })
    assert_equal "日本語 <title>", film.reload.title
    assert_equal " Original ", film.tmdb_metadata.fetch("original_title")
  end

  test "TMDB metadata is an independent JSON object and survives nested round trips" do
    metadata = { "original_title" => "Local title", "source" => { "languages" => [ "en", "ja" ] } }
    first = Registry::Film.create!(title: "First", tmdb_metadata: metadata)
    assert_equal({}, Registry::Film.new(title: "Second").tmdb_metadata)
    assert_equal metadata, first.reload.tmdb_metadata
    [ nil, [], "text", 42 ].each do |tmdb_metadata|
      film = Registry::Film.new(title: "Invalid metadata", tmdb_metadata: tmdb_metadata)
      assert_not film.valid?
      assert film.errors.of_kind?(:tmdb_metadata, :invalid)
    end
    assert_raises ActiveRecord::StatementInvalid do
      Registry::Film.transaction(requires_new: true) { Registry::Film.insert_all!([ { title: "Bypass", tmdb_metadata: [] } ]) }
    end
  end

  test "release year queries derive from the single date including year boundaries" do
    previous = Registry::Film.create!(title: "Previous", release_date: Date.new(1981, 12, 31))
    first = Registry::Film.create!(title: "First", release_date: Date.new(1982, 1, 1))
    last = Registry::Film.create!(title: "Last", release_date: Date.new(1982, 12, 31))
    following = Registry::Film.create!(title: "Following", release_date: Date.new(1983, 1, 1))
    unknown = Registry::Film.create!(title: "Unknown")
    films = Registry::Film.where(release_date: Date.new(1982, 1, 1)...Date.new(1983, 1, 1))
    assert_equal [ first.id, last.id ].sort, films.pluck(:id).sort
    assert_empty films.where(id: [ previous.id, following.id, unknown.id ])
  end

  test "external identity must be a positive integer when supplied" do
    [ 0, -1, 1.5, "no-id", "1.5" ].each do |tmdb_id|
      film = Registry::Film.new(title: "A film", tmdb_id: tmdb_id)
      assert_not film.valid?, tmdb_id.inspect
      assert film.errors[:tmdb_id].any?
    end
    assert Registry::Film.new(title: "A film", tmdb_id: 348).valid?
    assert Registry::Film.new(title: "Another film").valid?
  end

  test "present external identity is unique in validation and the database" do
    Registry::Film.create!(title: "First", tmdb_id: 348)
    duplicate = Registry::Film.new(title: "Second", tmdb_id: 348)
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:tmdb_id, :taken)
    assert_raises ActiveRecord::RecordNotUnique do
      Registry::Film.transaction(requires_new: true) do
        Registry::Film.insert_all!([ { title: "Bypass", tmdb_id: 348 } ])
      end
    end
    2.times { Registry::Film.create!(title: "Unknown identity") }
    assert_equal 2, Registry::Film.where(tmdb_id: nil).count
  end

  test "validation messages use English locale attributes without missing translations" do
    assert_equal :strict, Rails.application.config.i18n.raise_on_missing_translations
    I18n.with_locale(:en) do
      film = Registry::Film.new(tmdb_id: 0)
      assert_not film.valid?
      assert_includes film.errors.full_messages, "Title can't be blank"
      assert_includes film.errors.full_messages, "TMDB ID must be greater than 0"
      film = Registry::Film.new(title: "Invalid identity", tmdb_id: "not an integer")
      film.valid?
      assert_includes film.errors.full_messages, "TMDB ID is not a number"
      Registry::Film.create!(title: "First", tmdb_id: 348)
      film = Registry::Film.new(title: "Second", tmdb_id: 348)
      film.valid?
      assert_includes film.errors.full_messages, "TMDB ID has already been taken"
    end
  end
end
