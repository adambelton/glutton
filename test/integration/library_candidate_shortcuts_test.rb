require "test_helper"

class LibraryCandidateShortcutsRequestTest < ActionDispatch::IntegrationTest
  setup do
    controllers = [ LibraryController, RatingsController, RecommendationsController, SessionsController ]
    @forgery = controllers.to_h { |controller| [ controller, controller.allow_forgery_protection ] }
    controllers.each { |controller| controller.allow_forgery_protection = true }
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "Library shortcut film")
    authentication = Identity::Session.create!(user: @user)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: @user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  teardown do
    @forgery.each { |controller, enabled| controller.allow_forgery_protection = enabled }
  end

  def csrf_from_open_page
    Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def assert_no_success_flash
    assert_nil flash[:notice]
    assert_nil flash[:ratings_excluded_film_id]
    assert_nil flash[:recommendations_excluded_film_id]
  end

  {
    add_to_watchlist_from_ratings_path: :new_rating_path,
    mark_watched_from_recommendations_path: :recommendation_path
  }.each do |shortcut, destination|
    test "#{shortcut} rejects missing, malformed and unavailable film IDs" do
      get library_path
      token = csrf_from_open_page
      [ {}, { film_id: "0" }, { film_id: [ @film.id ] }, { film_id: Registry::Film.maximum(:id) + 1 } ].each do |input|
        assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
          post public_send(shortcut), params: input.merge(authenticity_token: token)
        end
        assert_response :see_other
        assert_redirected_to public_send(destination)
        assert_predicate flash[:alert], :present?
        assert_no_success_flash
      end
      assert_empty Library::LibraryFilm.where(user: @user)
    end

    test "#{shortcut} requires CSRF and an active identity" do
      assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count", "Identity::User.count" ] do
        post public_send(shortcut), params: { film_id: @film.id }
        assert_response :unprocessable_entity
        assert_no_success_flash

        reset!
        get new_session_path
        token = csrf_from_open_page
        post public_send(shortcut), params: { film_id: @film.id, authenticity_token: token }
        assert_response :unauthorized
        assert_no_success_flash
      end
      assert_empty Library::LibraryFilm.where(user: @user)
    end
  end

  test "a competing watched action makes a stale Watchlist submission fail without changing Library" do
    get new_rating_path
    token = csrf_from_open_page
    Library::CollectionManagement::MarkFilmWatched.call(user_id: @user.id, film_id: @film.id)

    assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
      post add_to_watchlist_from_ratings_path, params: { film_id: @film.id, authenticity_token: token }
    end
    assert_response :see_other
    assert_redirected_to new_rating_path
    assert_equal I18n.t("library.detail.watchlist_unavailable"), flash[:alert]
    assert_no_success_flash
    assert Library::LibraryFilm.find_by!(user: @user, film: @film).watched?
  end

  test "repeated watched submission creates no second event or success flash" do
    get recommendation_path
    token = csrf_from_open_page
    post mark_watched_from_recommendations_path, params: { film_id: @film.id, authenticity_token: token }
    assert_redirected_to recommendation_path
    assert_equal @film.id, flash[:recommendations_excluded_film_id]
    follow_redirect!

    assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
      post mark_watched_from_recommendations_path, params: { film_id: @film.id, authenticity_token: token }
    end
    assert_response :see_other
    assert_redirected_to recommendation_path
    assert_equal I18n.t("library.detail.watch_unavailable"), flash[:alert]
    assert_no_success_flash
    assert Library::LibraryFilm.find_by!(user: @user, film: @film).watched?
  end
end
