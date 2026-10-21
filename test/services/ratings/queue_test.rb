require "test_helper"

class Ratings::QueueTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @user = UserGuest.create!
  end

  def candidate(**attributes)
    RatingFilm.create!(user: @user, film: Film.create!(title: "Candidate film"), **attributes)
  end

  def candidates(**options)
    Ratings::NextCandidates.call(user_id: @user.id, **options)
  end

  def dismiss(rating_film, user = @user)
    Ratings::Dismiss.call(user_id: user.id, rating_film_id: rating_film.id)
  end

  test "empty queue does not admit catalogue or library films" do
    LibraryFilmWatched.create!(user: @user, film: Film.create!(title: "Library only"))
    Film.create!(title: "Catalogue only")
    assert_no_difference [ "RatingFilm.count", "LibraryFilm.count" ] do
      assert_empty candidates
    end
  end

  test "batches order by creation time then candidate id and isolate owners and dismissals" do
    recent = candidate
    first = candidate(created_at: 2.hours.ago)
    second = candidate(created_at: 2.hours.ago)
    candidate(dismissed: true, created_at: 1.day.ago)
    candidate(user: UserGuest.create!, created_at: 1.day.ago)
    assert_equal [ first.id, second.id ], candidates(limit: 2).map(&:id)
    assert_equal [ first.id, second.id, recent.id ], candidates.map(&:id)
  end

  test "default batch is five and requested limits are bounded" do
    6.times { candidate }
    assert_equal 5, candidates.size
    assert_equal 1, candidates(limit: 1).size
    assert_equal 6, candidates(limit: 100).size
    [ 0, -1, 101, nil, "5", 1.5 ].each do |limit|
      assert_raises(ArgumentError) { candidates(limit:) }
    end
  end

  test "unfinished candidates remain first across calls without selection writes" do
    first = candidate
    original_update = first.updated_at
    travel 1.hour
    second = candidate
    assert_no_difference "RatingFilm.count" do
      assert_equal [ first.id, second.id ], candidates.map(&:id)
      assert_equal [ first.id, second.id ], candidates.map(&:id)
    end
    assert_equal original_update, first.reload.updated_at
    dismiss(first)
    assert_equal [ second.id ], candidates.map(&:id)
  end

  test "dismissal requires no prior presentation and affects only Ratings" do
    film = candidate
    assert_no_difference [ "LibraryFilm.count", "DomainEvent.count", "RatingFilm.count" ] do
      assert_equal film.id, dismiss(film).id
    end
    assert film.reload.dismissed?
    assert_empty candidates
    travel 1.hour
    assert_empty candidates
    assert_raises(Ratings::DismissalUnavailable) { dismiss(film) }
  end

  test "missing and foreign rows fail without changing the candidate" do
    film = candidate
    assert_raises(Ratings::FilmUnavailable) { dismiss(film, UserGuest.create!) }
    assert_raises(Ratings::FilmUnavailable) { Ratings::Dismiss.call(user_id: @user.id, rating_film_id: -1) }
    assert_not film.reload.dismissed?
  end

  test "missing expired and deleted owners cannot select or dismiss" do
    film = candidate
    deleted = UserDeleted.create!
    travel UserGuest::EXPIRY_DURATION
    [ @user.id, deleted.id, -1 ].each do |user_id|
      assert_raises(Ratings::IdentityUnavailable) { Ratings::NextCandidates.call(user_id:) }
      assert_raises(Ratings::IdentityUnavailable) { Ratings::Dismiss.call(user_id:, rating_film_id: film.id) }
    end
    assert_not film.reload.dismissed?
  end

  test "outer rollback restores dismissal" do
    film = candidate
    RatingFilm.transaction(requires_new: true) do
      dismiss(film)
      raise ActiveRecord::Rollback
    end
    assert_not film.reload.dismissed?
  end

  test "failed dismissal is safely rescued in an outer transaction" do
    film = candidate
    connection = RatingFilm.connection
    connection.execute("ALTER TABLE rating_films ADD CONSTRAINT ratings_test_block_dismissal CHECK (NOT dismissed)")
    RatingFilm.transaction do
      assert_raises(ActiveRecord::StatementInvalid) { dismiss(film) }
      assert_not film.reload.dismissed?
      assert_equal [ film.id ], candidates.map(&:id)
    end
  ensure
    connection&.execute("ALTER TABLE rating_films DROP CONSTRAINT IF EXISTS ratings_test_block_dismissal")
  end
end
