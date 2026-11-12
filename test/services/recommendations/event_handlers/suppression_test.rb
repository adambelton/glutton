require "test_helper"

class Recommendations::SuppressionTest < ActiveSupport::TestCase
  setup do
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "Suppression film")
    @subscriptions = DomainEvents::Delivery::Subscriptions.all.select { |subscription| subscription.name.start_with?("recommendations.") }
  end

  def publish(publisher:, name:, **details)
    DomainEvents::DomainEvent.transaction do
      DomainEvents::Publication::Publish.call(user_id: @user.id, publisher:, name:, stream_key: "film:#{@film.id}",
        payload: { user_id: @user.id, film_id: @film.id, **details })
    end
  end

  def dispatch
    DomainEvents::Delivery::Dispatch.call(subscriptions: @subscriptions)
  end

  def library_event(name)
    publish(publisher: "library", name:)
    dispatch
  end

  def rating_event
    rating_film = Ratings::RatingFilm.create!(user: @user, film: @film)
    Ratings::RatingRecording::SubmitRating.call(user_id: @user.id, rating_film_id: rating_film.id, value: "brilliant")
    dispatch
  end

  def recommendation_film
    Recommendations::RecommendationFilm.find_by(user: @user, film: @film)
  end

  test "Watchlist removal discards a suppression-only record and repeated events have no effect" do
    assert_equal({ ignored: 1 }, library_event("FilmRemovedFromWatchlist"))
    assert_nil recommendation_film
    assert_equal({ processed: 1 }, library_event("FilmAddedToWatchlist"))
    assert recommendation_film.suppressed?
    assert_nil recommendation_film.response
    assert_equal({ ignored: 1 }, library_event("FilmAddedToWatchlist"))
    assert_equal({ processed: 1 }, library_event("FilmRemovedFromWatchlist"))
    assert_nil recommendation_film
    assert_equal({ ignored: 1 }, library_event("FilmRemovedFromWatchlist"))
    assert_empty dispatch
  end

  test "Watchlist removal keeps a previously recommended film suppressed" do
    own = Recommendations::RecommendationFilm.create!(user: @user, film: @film, recommended_at: Time.current)
    recommended_at = own.reload.recommended_at

    assert_equal({ processed: 1 }, library_event("FilmAddedToWatchlist"))
    assert_equal({ ignored: 1 }, library_event("FilmRemovedFromWatchlist"))
    assert own.reload.suppressed?
    assert_equal recommended_at, own.recommended_at
  end

  test "a submitted rating suppresses the recommendation without recording a response" do
    assert_equal({ processed: 1 }, rating_event)
    assert recommendation_film.suppressed?
    assert_nil recommendation_film.response
    assert_empty dispatch
  end

  test "watched suppression preserves the recommendation response and viewer isolation" do
    own = Recommendations::RecordFilmResponse.call(user_id: @user.id, film_id: @film.id, response: "rejected")
    other = Recommendations::RecommendationFilm.create!(user: Identity::UserGuest.create!, film: @film, recommended_at: Time.current)
    library_event("FilmMarkedWatched")
    assert own.reload.suppressed?
    assert_equal "rejected", own.response
    assert_not other.reload.suppressed?
    assert_equal({ ignored: 1 }, library_event("FilmMarkedWatched"))
    assert_equal({ ignored: 1 }, library_event("FilmRemovedFromWatchlist"))
    assert own.reload.suppressed?
  end
end
