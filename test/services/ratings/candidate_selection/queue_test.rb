require "test_helper"

class Ratings::QueueTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @user = Identity::UserGuest.create!
  end

  def candidate(**attributes)
    Ratings::RatingFilm.create!(user: @user, film: Registry::Film.create!(title: "Candidate film"), **attributes)
  end

  def candidates(**options)
    Ratings::CandidateSelection::NextCandidates.call(user_id: @user.id, **options)
  end

  def dismiss(rating_film, user = @user)
    Ratings::CandidateSelection::Dismiss.call(user_id: user.id, rating_film_id: rating_film.id)
  end

  def catalogue_film(title, votes: nil)
    Registry::Film.create!(title:, tmdb_metadata: { details: { vote_count: votes } })
  end

  test "empty queue admits catalogue and watched films without touching shared or personal evidence" do
    film = catalogue_film("CatalogueQueries", votes: 100)
    watched = catalogue_film("Watched", votes: 50)
    Library::LibraryFilm.create!(watched: true, user: @user, film: watched)
    assert_no_difference [ "Registry::Film.count", "Library::LibraryFilm.count", "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      assert_difference "Ratings::RatingFilm.count", 2 do
        assert_equal [ film.id, watched.id ], candidates(limit: 2).map(&:film_id)
      end
    end
  end

  test "default automatic admission creates one row without a hidden buffer" do
    7.times { |index| catalogue_film("Film #{index}", votes: index) }
    assert_difference "Ratings::RatingFilm.count", 1 do
      assert_equal 1, candidates.size
    end
    assert_no_difference "Ratings::RatingFilm.count" do
      assert_equal 1, candidates.size
    end
  end

  test "admission ranks valid vote counts descending with missing values last and stable ties" do
    missing = catalogue_film("Missing")
    malformed = catalogue_film("Malformed", votes: "99999")
    low = catalogue_film("Zero", votes: 0)
    first = catalogue_film("Tie first", votes: 100)
    high = catalogue_film("Most voted", votes: 500)
    second = catalogue_film("Tie second", votes: 100)
    assert_difference "Ratings::RatingFilm.count", 6 do
      assert_equal [ high, first, second, low, missing, malformed ].map(&:id), candidates(limit: 100).map(&:film_id)
    end
  end

  test "only requested shortfalls are admitted and existing unfinished order stays authoritative" do
    existing = candidate
    low = catalogue_film("Lower", votes: 1)
    high = catalogue_film("Higher", votes: 100)
    assert_difference "Ratings::RatingFilm.count", 1 do
      assert_equal [ existing.film_id, high.id ], candidates(limit: 2).map(&:film_id)
    end
    assert_no_difference "Ratings::RatingFilm.count" do
      assert_equal [ existing.film_id, high.id ], candidates(limit: 2).map(&:film_id)
    end
    assert_difference "Ratings::RatingFilm.count", 1 do
      assert_equal [ existing.film_id, high.id, low.id ], candidates(limit: 3).map(&:film_id)
    end
  end

  test "Library classifications affect eligibility only after Ratings consumes their events" do
    watchlisted = catalogue_film("Watchlisted", votes: 1000)
    unclassified = catalogue_film("Unclassified", votes: 900)
    Library::LibraryFilm.create!(user: @user, film: watchlisted)
    existing = Ratings::RatingFilm.create!(user: @user, film: watchlisted)

    assert_equal existing.id, candidates(limit: 1).sole.id
    assert_difference "Ratings::RatingFilm.count", 1 do
      assert_equal [ watchlisted.id, unclassified.id ], candidates(limit: 2).map(&:film_id)
    end
  end

  test "removing Library exclusions does not silently release holds or restore dismissals" do
    held_film = catalogue_film("Suppressed", votes: 100)
    dismissed_film = catalogue_film("Dismissed", votes: 90)
    suppressed = Ratings::RatingFilm.create!(user: @user, film: held_film, suppressed: true)
    dismissed = Ratings::RatingFilm.create!(user: @user, film: dismissed_film, dismissed: true)
    watchlist = Library::LibraryFilm.create!(user: @user, film: held_film)
    Library::CollectionManagement::RemoveFromWatchlist.call(user_id: @user.id, library_film_id: watchlist.id)
    assert_no_difference "Ratings::RatingFilm.count" do
      assert_empty candidates
    end
    assert suppressed.reload.suppressed?
    assert dismissed.reload.dismissed?
  end

  test "exhaustion preserves rated dismissed suppressed rows and later catalogue films become available" do
    rows = [ candidate(dismissed: true), candidate(suppressed: true), candidate ]
    rows.last.submit_rating!(value: Ratings::Rating::Values::PRETTY_GOOD)
    assert_no_difference "Ratings::RatingFilm.count" do
      assert_empty candidates
      assert_empty candidates
    end
    film = catalogue_film("Newly available", votes: 100)
    assert_equal [ film.id ], candidates.map(&:film_id)
    assert rows.first.reload.dismissed?
    assert rows.second.reload.suppressed?
    assert_equal Ratings::Rating::Values::PRETTY_GOOD, rows.last.reload.current_rating.value
  end

  test "batches order by creation time then candidate id and isolate owners and dismissals" do
    recent = candidate
    first = candidate(created_at: 2.hours.ago)
    second = candidate(created_at: 2.hours.ago)
    candidate(dismissed: true, created_at: 1.day.ago)
    foreign = candidate(user: Identity::UserGuest.create!, created_at: 1.day.ago)
    assert_equal [ first.id, second.id ], candidates(limit: 2).map(&:id)
    batch = candidates(limit: 4)
    assert_equal [ first.id, second.id, recent.id ], batch.first(3).map(&:id)
    assert_equal foreign.film_id, batch.last.film_id
    assert_equal @user.id, batch.last.user_id
  end

  test "explicit batch limits are bounded" do
    6.times { candidate }
    assert_equal 5, candidates(limit: 5).size
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
    assert_no_difference "Ratings::RatingFilm.count" do
      assert_equal [ first.id, second.id ], candidates(limit: 2).map(&:id)
      assert_equal [ first.id, second.id ], candidates(limit: 2).map(&:id)
    end
    assert_equal original_update, first.reload.updated_at
    dismiss(first)
    assert_equal [ second.id ], candidates.map(&:id)
  end

  test "dismissal requires no prior presentation and affects only Ratings" do
    film = candidate
    assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count", "Ratings::RatingFilm.count" ] do
      assert_equal film.id, dismiss(film).id
    end
    assert film.reload.dismissed?
    assert_empty candidates
    travel 1.hour
    assert_empty candidates
    assert_raises(Ratings::Errors::DismissalUnavailable) { dismiss(film) }
  end

  test "missing and foreign rows fail without changing the candidate" do
    film = candidate
    assert_raises(Ratings::Errors::FilmUnavailable) { dismiss(film, Identity::UserGuest.create!) }
    assert_raises(Ratings::Errors::FilmUnavailable) { Ratings::CandidateSelection::Dismiss.call(user_id: @user.id, rating_film_id: -1) }
    assert_not film.reload.dismissed?
  end

  test "missing expired and deleted owners cannot select or dismiss" do
    film = candidate
    deleted = Identity::UserDeleted.create!
    travel Identity::UserGuest::EXPIRY_DURATION
    [ @user.id, deleted.id, -1 ].each do |user_id|
      assert_raises(Identity::Errors::Unavailable) { Ratings::CandidateSelection::NextCandidates.call(user_id:) }
      assert_raises(Identity::Errors::Unavailable) { Ratings::CandidateSelection::Dismiss.call(user_id:, rating_film_id: film.id) }
    end
    assert_not film.reload.dismissed?
  end

  test "outer rollback restores dismissal" do
    film = candidate
    Ratings::RatingFilm.transaction(requires_new: true) do
      dismiss(film)
      raise ActiveRecord::Rollback
    end
    assert_not film.reload.dismissed?
  end

  test "failed dismissal is safely rescued in an outer transaction" do
    film = candidate
    connection = Ratings::RatingFilm.connection
    connection.execute("ALTER TABLE rating_films ADD CONSTRAINT ratings_test_block_dismissal CHECK (NOT dismissed)")
    Ratings::RatingFilm.transaction do
      assert_raises(ActiveRecord::StatementInvalid) { dismiss(film) }
      assert_not film.reload.dismissed?
      assert_equal [ film.id ], candidates.map(&:id)
    end
  ensure
    connection&.execute("ALTER TABLE rating_films DROP CONSTRAINT IF EXISTS ratings_test_block_dismissal")
  end
end
