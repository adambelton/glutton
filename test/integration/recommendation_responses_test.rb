require "test_helper"
require_relative "../support/assessed_recommendation_films"

class RecommendationResponsesRequestTest < ActionDispatch::IntegrationTest
  include AssessedRecommendationFilms

  setup do
    controllers = [ RecommendationsController, SessionsController ]
    @forgery = controllers.to_h { |controller| [ controller, controller.allow_forgery_protection ] }
    controllers.each { |controller| controller.allow_forgery_protection = true }
    @film = Registry::Film.create!(title: "Recommended film")
    @user = Identity::UserGuest.create!
    authentication = Identity::Session.create!(user: @user)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: @user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  teardown do
    @forgery.each { |controller, enabled| controller.allow_forgery_protection = enabled }
  end

  def submitted_values
    form = Nokogiri::HTML(response.body).at_css("form[action='#{accept_recommendation_path}']")
    { film_id: form.at_css('input[name="film_id"]')["value"], authenticity_token: csrf_from_open_page }
  end

  def csrf_from_open_page
    Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  test "navigation renders the lock without admitting a recommendation" do
    assert_no_difference "Recommendations::RecommendationFilm.count" do
      get library_path
      assert_select '.ui-nav [role="link"][aria-disabled="true"]'
      assert_select ".ui-nav a[href=?]", recommendation_path, count: 0
    end

    unlock_recommendations_for(user: @user)
    assert_no_difference "Recommendations::RecommendationFilm.count" do
      get library_path
      assert_select ".ui-nav a[href=?]", recommendation_path
    end
  end

  test "shows stored film facts and a trailer when available" do
    film = Registry::Film.create!(title: "Film with a trailer", release_date: Date.new(2025, 1, 1),
      tmdb_metadata: { details: {
        runtime: 97, genres: [ { name: "Horror" } ], overview: "A film synopsis.",
        videos: { results: [ { site: "YouTube", type: "Trailer", official: true, key: "M7lc1UVf-VE" } ] }
      } })
    unlock_recommendations_for(user: @user)
    get recommendation_path
    assert_response :success
    assert_select "h2", @film.title
    assert_select "iframe", count: 0

    Recommendations::RecordFilmResponse.call(user_id: @user.id, film_id: @film.id, response: "rejected")
    get recommendation_path
    assert_response :success
    assert_select "h2", "#{film.title} (2025)"
    assert_select ".recommendation-details h2 .film-year", "(2025)"
    assert_select ".recommendation-facts", count: 0
    assert_select ".recommendation-trailer h2", count: 0
    assert_select "iframe[src=?][title=?]", "https://www.youtube.com/embed/M7lc1UVf-VE",
      I18n.t("recommendations.trailer_for", title: film.title)
    assert_select "a[href=?]", "https://www.youtube.com/watch?v=M7lc1UVf-VE", count: 0
  end

  test "a stale or repeated submission fails without changing the recorded choice" do
    unlock_recommendations_for(user: @user)
    get recommendation_path
    assert_response :success
    submitted = submitted_values
    post reject_recommendation_path, params: submitted
    assert_redirected_to recommendation_path
    follow_redirect!
    assert_equal "rejected", Recommendations::RecommendationFilm.find_by!(user: @user, film: @film).response

    assert_no_difference [ "Recommendations::RecommendationFilm.count", "DomainEvents::DomainEvent.count" ] do
      post accept_recommendation_path, params: submitted
      assert_response :conflict
      assert_select '[role="alert"]', I18n.t("recommendations.response_unavailable")
      assert_select "a[href=?]", recommendation_path, text: I18n.t("recommendations.return")
      assert_nil flash[:notice]

      post reject_recommendation_path, params: submitted
      assert_response :conflict
    end
    assert_equal "rejected", Recommendations::RecommendationFilm.find_by!(user: @user, film: @film).response
  end

  test "invalid identifiers and unavailable films record nothing" do
    unlock_recommendations_for(user: @user)
    get recommendation_path
    assert_response :success
    submitted = submitted_values
    assert_no_difference [ "Recommendations::RecommendationFilm.count", "DomainEvents::DomainEvent.count" ] do
      post accept_recommendation_path, params: submitted.except(:film_id)
      assert_response :bad_request
      assert_select '[role="alert"]', I18n.t("recommendations.invalid_film")

      post reject_recommendation_path, params: submitted.merge(film_id: [ submitted.fetch(:film_id) ])
      assert_response :bad_request

      post accept_recommendation_path, params: submitted.merge(film_id: Registry::Film.maximum(:id) + 1)
      assert_response :conflict
    end
    assert_nil Recommendations::RecommendationFilm.find_by!(user: @user, film: @film).response
  end

  test "responses require CSRF and an identified viewer" do
    unlock_recommendations_for(user: @user)
    get recommendation_path
    assert_response :success
    submitted = submitted_values
    assert_no_difference [ "Recommendations::RecommendationFilm.count", "DomainEvents::DomainEvent.count", "Identity::User.count" ] do
      post accept_recommendation_path, params: submitted.except(:authenticity_token)
      assert_response :unprocessable_entity

      reset!
      get new_session_path
      post reject_recommendation_path, params: submitted.merge(authenticity_token: csrf_from_open_page)
      assert_response :unauthorized
    end
    assert_nil Recommendations::RecommendationFilm.find_by!(user: @user, film: @film).response
  end
end
