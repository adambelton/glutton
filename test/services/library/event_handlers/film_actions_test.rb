require "test_helper"

class Library::FilmActionsTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "Film in the catalogue")
  end

  def dispatch
    DomainEvents::Delivery::Dispatch.call
  end

  def accept_recommendation
    Recommendations::RecordFilmResponse.call(user_id: @user.id, film_id: @film.id, response: "accepted")
  end

  test "acceptance adds a Watchlist entry through delivery and publishes a causal fact" do
    recommendation_film = accept_recommendation
    assert_not Library::LibraryFilm.exists?(user: @user, film: @film)

    dispatch
    entry = Library::LibraryFilm.find_by!(user: @user, film: @film)
    assert_not entry.watched?
    source = DomainEvents::DomainEvent.find_by!(name: "RecommendationAccepted")
    fact = DomainEvents::DomainEvent.find_by!(name: "FilmAddedToWatchlist", causation_id: source.id)
    assert_equal source.correlation_id, fact.correlation_id
    assert_equal({ "user_id" => @user.id, "film_id" => @film.id }, fact.payload)
    assert_equal "accepted", recommendation_film.reload.response
    assert_empty dispatch
  end

  test "acceptance does not duplicate a direct Watchlist addition" do
    Library::CollectionManagement::AddToWatchlist.call(user_id: @user.id, film_id: @film.id)
    recommendation_film = accept_recommendation
    assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
      dispatch
    end
    assert_equal "accepted", recommendation_film.reload.response
    assert recommendation_film.suppressed?
  end

  test "a pending acceptance adds to Watchlist after a separate direct addition and removal" do
    recommendation_film = accept_recommendation
    entry = Library::CollectionManagement::AddToWatchlist.call(user_id: @user.id, film_id: @film.id)
    Library::CollectionManagement::RemoveFromWatchlist.call(user_id: @user.id, library_film_id: entry.id)
    assert_not Library::LibraryFilm.exists?(user: @user, film: @film)

    dispatch

    restored = Library::LibraryFilm.find_by!(user: @user, film: @film)
    assert_not_equal entry.id, restored.id
    assert_not restored.watched?
    assert_equal "accepted", recommendation_film.reload.response
    source = DomainEvents::DomainEvent.find_by!(name: "RecommendationAccepted")
    assert DomainEvents::DomainEvent.exists?(name: "FilmAddedToWatchlist", causation_id: source.id)
  end

  test "direct Watched action creates an entry without a recommendation response" do
    entry = Library::CollectionManagement::AddToWatched.call(user_id: @user.id, film_id: @film.id)
    assert entry.watched?
    dispatch
    recommendation_film = Recommendations::RecommendationFilm.find_by!(user: @user, film: @film)
    assert recommendation_film.suppressed?
    assert_nil recommendation_film.response
    assert_raises(Library::Errors::AddToWatchedUnavailable) do
      Library::CollectionManagement::AddToWatched.call(user_id: @user.id, film_id: @film.id)
    end
  end

  test "direct Watched admission rejects an existing Watchlist entry" do
    entry = Library::CollectionManagement::AddToWatchlist.call(user_id: @user.id, film_id: @film.id)

    assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
      assert_raises(Library::Errors::AddToWatchedUnavailable) do
        Library::CollectionManagement::AddToWatched.call(user_id: @user.id, film_id: @film.id)
      end
    end
    assert_not entry.reload.watched?
  end

  test "a failure applying an acceptance rolls back Library and retries independently" do
    recommendation_film = accept_recommendation
    callback = lambda do |event|
      raise ActiveRecord::StatementInvalid, "injected Library publication failure" if event.name == "FilmAddedToWatchlist"
    end
    DomainEvents::DomainEvent.set_callback(:create, :before, callback)
    assert_no_difference "Library::LibraryFilm.count" do
      assert_equal({ retrying: 1 }, dispatch)
    end
    assert_equal "accepted", recommendation_film.reload.response
    DomainEvents::DomainEvent.skip_callback(:create, :before, callback)
    travel 5.seconds
    dispatch
    assert Library::LibraryFilm.exists?(user: @user, film: @film)
  ensure
    DomainEvents::DomainEvent.skip_callback(:create, :before, callback, raise: false) if callback
  end
end
