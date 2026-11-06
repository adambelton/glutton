require "test_helper"

class Registry::TmdbMetadataTest < ActiveSupport::TestCase
  test "exposes only usable display values without modifying stored provider data" do
    details = { "overview" => [ "unexpected" ], "tagline" => "", "runtime" => "117", "poster_path" => 123,
      "original_language" => false, "status" => {}, "imdb_id" => 99, "original_title" => [],
      "genres" => "Horror", "production_companies" => [ nil, "company", { "name" => [] }, { "name" => "Studio" } ],
      "production_countries" => [ { "name" => "United Kingdom", "unconsumed" => true } ],
      "spoken_languages" => [ { "english_name" => "English", "name" => "Native" }, { "english_name" => [], "name" => "日本語" } ] }
    metadata = { "details" => details }.freeze
    reader = Registry::TmdbMetadata.new(metadata)
    %i[overview tagline runtime poster_path original_language status imdb_id original_title].each do |attribute|
      assert_nil reader.public_send(attribute)
    end
    assert_empty reader.genre_names
    assert_equal [ "Studio" ], reader.production_company_names
    assert_equal [ "United Kingdom" ], reader.production_country_names
    assert_equal [ "English", "日本語" ], reader.spoken_language_names
  end

  test "valid values and legacy original titles remain readable" do
    reader = Registry::TmdbMetadata.new("original_title" => "Legacy title", "details" => {
      "overview" => "  Synopsis  ", "poster_path" => "/poster.jpg", "runtime" => 117, "genres" => [ { "name" => "Horror" } ] })
    assert_equal "Legacy title", reader.original_title
    assert_equal "  Synopsis  ", reader.overview
    assert_equal "/poster.jpg", reader.poster_path
    assert_equal 117, reader.runtime
    assert_equal [ "Horror" ], reader.genre_names
    assert_nil Registry::TmdbMetadata.new("details" => { "runtime" => -1 }).runtime
    assert_equal "Source title", Registry::TmdbMetadata.new("original_title" => "Legacy", "details" => { "original_title" => "Source title" }).original_title
  end
end
