require "test_helper"

class Registry::PreviewFilmsTest < ActiveSupport::TestCase
  test "curated film reads preserve requested order and omit absent identities without personal records" do
    assert_empty Registry::CatalogueQueries::PreviewFilms.call(tmdb_ids: [ 348, 1091 ])
    first = Registry::Film.create!(title: "First", tmdb_id: 348)
    second = Registry::Film.create!(title: "Second", tmdb_id: 1091)
    Registry::Film.create!(title: "Outside the example set", tmdb_id: 694)
    assert_no_difference [ "Identity::User.count", "Ratings::RatingFilm.count", "Library::LibraryFilm.count" ] do
      assert_equal [ second, first ], Registry::CatalogueQueries::PreviewFilms.call(tmdb_ids: [ 1091, 999999, 348 ])
    end
  end
end
