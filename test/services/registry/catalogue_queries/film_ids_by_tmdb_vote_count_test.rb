require "test_helper"

class Registry::FilmIdsByTmdbVoteCountTest < ActiveSupport::TestCase
  test "returns a bounded ordering with exclusions, stable ties and missing counts last" do
    missing = film("Missing")
    malformed = film("Malformed", "900")
    zero = film("Zero", 0)
    first = film("First tie", 20)
    second = film("Second tie", 20)
    excluded = film("Excluded", 100)

    assert_equal [ first.id, second.id, zero.id ], ordered_ids(excluded, limit: 3)
    assert_equal [ first.id, second.id, zero.id, missing.id, malformed.id ], ordered_ids(excluded, limit: 10)
  end

  private

  def film(title, vote_count = nil)
    Registry::Film.create!(title:, tmdb_metadata: { details: { vote_count: } })
  end

  def ordered_ids(excluded, limit:)
    Registry::CatalogueQueries::FilmIdsByTmdbVoteCount.call(excluding_ids: [ excluded.id ], limit:)
  end
end
