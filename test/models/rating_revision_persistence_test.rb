require "test_helper"

class RatingRevisionPersistenceTest < ActiveSupport::TestCase
  setup do
    @user = UserGuest.create!
    @film = Film.create!(title: "Revision storage")
    @rating_film = RatingFilm.create!(user: @user, film: @film)
    @rating = @rating_film.submit_rating!(value: Rating::Values::BRILLIANT)
  end

  def insert(**attributes)
    Rating.transaction(requires_new: true) do
      Rating.insert_all!([ { rating_film_id: @rating_film.id, value: Rating::Values::GARBAGE }.merge(attributes) ])
    end
  end

  test "latest IDs select one current rating per candidate despite equal or backdated timestamps" do
    other = RatingFilm.create!(user: @user, film: Film.create!(title: "Another film"))
    other_rating = other.submit_rating!(value: Rating::Values::GARBAGE)
    2.times { insert(created_at: @rating.created_at - 1.day) }
    latest = @rating_film.ratings.order(id: :desc).first
    assert_equal 3, @rating_film.ratings.count
    assert_equal latest.id, @rating_film.reload.current_rating.id
    assert_equal [ latest.id ], @rating_film.ratings.current.pluck(:id)
    assert_equal [ other_rating.id, latest.id ].sort, Rating.current.order(:id).pluck(:id)
    assert_equal other_rating.id, other.reload.current_rating.id
  end

  test "fresh storage accepts history without changing the earlier rating" do
    insert
    assert_equal Rating::Values::BRILLIANT, @rating.reload.value
    assert_equal 2, @rating_film.ratings.count
    assert_equal @rating_film.ratings.maximum(:id), @rating_film.reload.current_rating.id
    assert Rating.connection.index_exists?(:ratings, [ :rating_film_id, :id ])
  end

  test "model replacement failure preserves the previous current rating" do
    assert_raises(ActiveRecord::RecordInvalid) do
      @rating_film.revise_rating!(previous_rating_id: @rating.id, value: "invalid")
    end
    assert_equal @rating.id, @rating_film.reload.current_rating.id
    assert_equal 1, @rating_film.ratings.count
  end
end
