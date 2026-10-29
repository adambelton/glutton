require "test_helper"

class FilmTest < ActiveSupport::TestCase
  test "filling TMDB metadata preserves local fields and the first retained source snapshot" do
    film = Film.create!(title: "Local title", tmdb_id: 348, metadata: { note: "Keep" })
    assert_not film.tmdb_metadata?
    film.fill_tmdb_metadata!(metadata: { "tmdb" => { "details" => { "overview" => "Original source" } } })
    assert film.reload.tmdb_metadata?
    assert_equal "Keep", film.metadata["note"]
    film.fill_tmdb_metadata!(metadata: { "tmdb" => { "details" => { "overview" => "Replacement" } }, "note" => "Overwrite" })
    assert_equal "Original source", film.reload.metadata.dig("tmdb", "details", "overview")
    assert_equal "Keep", film.metadata["note"]
    assert_equal "Local title", film.title
  end

  test "minimal and complete metadata retain their own identities" do
    minimal = Film.create!(title: "A film")
    assert_equal "A film", minimal.reload.title
    assert_equal({}, minimal.metadata)
    assert_nil minimal.release_date
    assert_nil minimal.tmdb_id

    attributes = { title: "A film", metadata: { "original_title" => "Original title" }, release_date: Date.new(1982, 6, 25), tmdb_id: 1091 }
    complete = Film.create!(attributes)
    assert_equal attributes.stringify_keys, complete.reload.slice(*attributes.keys.map(&:to_s))
    assert_not_equal minimal.id, complete.id
    another = Film.create!(attributes.merge(tmdb_id: 999))
    assert_not_equal complete.id, another.id
    assert_equal complete.release_date, another.release_date
  end

  test "title is required and metadata remains unmodified" do
    [ nil, "", " \t" ].each do |title|
      film = Film.new(title: title)
      assert_not film.valid?
      assert film.errors.of_kind?(:title, :blank)
    end
    film = Film.create!(title: "日本語 <title>", metadata: { original_title: " Original " })
    assert_equal "日本語 <title>", film.reload.title
    assert_equal " Original ", film.metadata.fetch("original_title")
  end

  test "metadata is an independent JSON object and survives nested round trips" do
    first = Film.new(title: "First")
    second = Film.new(title: "Second")
    first.metadata["original_title"] = "Local title"
    assert_equal({}, second.metadata)
    first.metadata["source"] = { "languages" => [ "en", "ja" ] }
    first.save!
    assert_equal({ "original_title" => "Local title", "source" => { "languages" => [ "en", "ja" ] } }, first.reload.metadata)
    [ nil, [], "text", 42 ].each do |metadata|
      film = Film.new(title: "Invalid metadata", metadata: metadata)
      assert_not film.valid?
      assert film.errors.of_kind?(:metadata, :invalid)
    end
    assert_raises ActiveRecord::StatementInvalid do
      Film.transaction(requires_new: true) { Film.insert_all!([ { title: "Bypass", metadata: [] } ]) }
    end
  end

  test "release year queries derive from the single date including year boundaries" do
    previous = Film.create!(title: "Previous", release_date: Date.new(1981, 12, 31))
    first = Film.create!(title: "First", release_date: Date.new(1982, 1, 1))
    last = Film.create!(title: "Last", release_date: Date.new(1982, 12, 31))
    following = Film.create!(title: "Following", release_date: Date.new(1983, 1, 1))
    unknown = Film.create!(title: "Unknown")
    films = Film.where(release_date: Date.new(1982, 1, 1)...Date.new(1983, 1, 1))
    assert_equal [ first.id, last.id ].sort, films.pluck(:id).sort
    assert_empty films.where(id: [ previous.id, following.id, unknown.id ])
  end

  test "external identity must be a positive integer when supplied" do
    [ 0, -1, 1.5, "no-id", "1.5" ].each do |tmdb_id|
      film = Film.new(title: "A film", tmdb_id: tmdb_id)
      assert_not film.valid?, tmdb_id.inspect
      assert film.errors[:tmdb_id].any?
    end
    assert Film.new(title: "A film", tmdb_id: 348).valid?
    assert Film.new(title: "Another film").valid?
  end

  test "present external identity is unique in validation and the database" do
    Film.create!(title: "First", tmdb_id: 348)
    duplicate = Film.new(title: "Second", tmdb_id: 348)
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:tmdb_id, :taken)
    assert_raises ActiveRecord::RecordNotUnique do
      Film.transaction(requires_new: true) do
        Film.insert_all!([ { title: "Bypass", tmdb_id: 348 } ])
      end
    end
    2.times { Film.create!(title: "Unknown identity") }
    assert_equal 2, Film.where(tmdb_id: nil).count
  end

  test "validation messages use English locale attributes without missing translations" do
    assert_equal :strict, Rails.application.config.i18n.raise_on_missing_translations
    I18n.with_locale(:en) do
      film = Film.new(tmdb_id: 0)
      assert_not film.valid?
      assert_includes film.errors.full_messages, "Title can't be blank"
      assert_includes film.errors.full_messages, "TMDB ID must be greater than 0"
      film.tmdb_id = "not an integer"
      film.valid?
      assert_includes film.errors.full_messages, "TMDB ID is not a number"
      Film.create!(title: "First", tmdb_id: 348)
      film.assign_attributes(title: "Second", tmdb_id: 348)
      film.valid?
      assert_includes film.errors.full_messages, "TMDB ID has already been taken"
    end
  end
end
