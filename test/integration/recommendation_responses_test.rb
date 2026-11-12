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
    assert_not Recommendations::RecommendationFilm.exists?(user: @user, film: @film)
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
    assert_not Recommendations::RecommendationFilm.exists?(user: @user, film: @film)
  end
end
