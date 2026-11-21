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
      assert_select '.ui-nav [aria-describedby="recommendations-nav-tooltip"][aria-disabled="true"]'
      assert_select ".ui-nav a[href=?]", recommendation_path, count: 0
    end

    unlock_recommendations_for(user: @user)
    assert_no_difference "Recommendations::RecommendationFilm.count" do
      get library_path
      assert_select ".ui-nav a[href=?]", recommendation_path
    end
  end

  test "availability returns the current viewer's lock status without caching" do
    get availability_recommendation_path, as: :json
    assert_response :accepted
    assert_includes response.headers["Cache-Control"], "no-store"

    unlock_recommendations_for(user: @user)
    assert_no_difference "Recommendations::RecommendationFilm.count" do
      get availability_recommendation_path, as: :json
      assert_response :no_content
      assert_includes response.headers["Cache-Control"], "no-store"
    end

    open_session do |signed_out|
      signed_out.get availability_recommendation_path, as: :json
      signed_out.assert_response :unauthorized
    end
  end

  test "shows stored film facts and falls back to a trailer when no official one is listed" do
    film = Registry::Film.create!(title: "Film with a trailer", release_date: Date.new(2025, 1, 1),
      tmdb_metadata: { details: {
        runtime: 97, genres: [ { name: "Horror" } ], overview: "A film synopsis.",
        videos: { results: [
          { site: "YouTube", type: "Teaser", official: false, key: "Q82CFO_OvmY", iso_639_1: "en" },
          { site: "YouTube", type: "Trailer", official: false, key: "JarbtubycQg", iso_639_1: "en" }
        ] }
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
    assert_select "iframe[src=?][title=?][referrerpolicy='strict-origin-when-cross-origin']", "https://www.youtube.com/embed/JarbtubycQg",
      I18n.t("recommendations.trailer_for", title: film.title)
    assert_select "a[href=?]", "https://www.youtube.com/watch?v=JarbtubycQg", count: 0
  end

  test "displays a percentage only when the current viewer has enough relevant evidence" do
    quality_set = 5.times.map { |index| quality_categories(:tone).qualities.create!(name: "Match quality #{index}") }
    quality_set.each { |quality| Registry::FilmQuality.create!(film: @film, quality:) }
    8.times do |index|
      viewer = index < 7 ? @user : Identity::UserGuest.create!
      film = Registry::Film.create!(title: "Match source #{index}")
      quality_set.each { |quality| Registry::FilmQuality.create!(film:, quality:) }
      rating = Ratings::RatingFilm.create!(user: viewer, film:).submit_rating!(value: "brilliant")
      Ratings::QualityScoring::ScoreRatingQualities.call(rating_id: rating.id)
      Recommendations::RecommendationFilm.new(user: @user, film:).suppress!
    end

    get recommendation_path
    assert_select "h2", @film.title
    assert_select ".recommendation-match", I18n.t("recommendations.match.limited")

    film = Registry::Film.create!(title: "Eighth current viewer source")
    quality_set.each { |quality| Registry::FilmQuality.create!(film:, quality:) }
    rating = Ratings::RatingFilm.create!(user: @user, film:).submit_rating!(value: "brilliant")
    Ratings::QualityScoring::ScoreRatingQualities.call(rating_id: rating.id)
    get recommendation_path

    assert_select "h2", @film.title
    tooltip_id = "recommendation-match-tooltip-#{@film.id}"
    assert_select ".recommendation-match[aria-describedby=?]", tooltip_id do
      assert_select ".recommendation-match-value", I18n.t("recommendations.match.percentage", percentage: 65)
      assert_select '[role="tooltip"][id=?]', tooltip_id, I18n.t("recommendations.match.label")
    end
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
