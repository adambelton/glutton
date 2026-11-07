require "test_helper"

class RatingsDiscoveryTest < ActionDispatch::IntegrationTest
  setup do
    @controllers = [ RatingsController, SessionsController, GuestSessionsController ]
    @forgery = @controllers.to_h { |controller| [ controller, controller.allow_forgery_protection ] }
    @controllers.each { |controller| controller.allow_forgery_protection = true }
    SessionsController::RATE_LIMIT_STORE.clear
    GuestSessionsController::RATE_LIMIT_STORE.clear
    @film = Registry::Film.create!(title: "Most familiar", tmdb_metadata: { details: { vote_count: 100 } })
    @next_film = Registry::Film.create!(title: "Next familiar", tmdb_metadata: { details: { vote_count: 50 } })
  end

  teardown { @forgery.each { |controller, enabled| controller.allow_forgery_protection = enabled } }

  def token
    Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  test "anonymous preview stays read only and explicit guest entry admits one film at a time" do
    assert_no_difference [ "Identity::User.count", "Ratings::RatingFilm.count" ] do
      get root_path
      get new_rating_path
      assert_redirected_to new_session_path
    end
    get new_session_path
    post guest_session_path, params: { authenticity_token: token }
    assert_redirected_to new_rating_path
    assert_difference "Ratings::RatingFilm.count", 1 do
      follow_redirect!
      assert_select "h2", @film.title
    end
    row = Ratings::RatingFilm.sole
    assert_no_difference [ "Ratings::RatingFilm.count", "Ratings::Rating.count" ] do
      post rating_path, params: { rating_film_id: row.id, value: "invalid", authenticity_token: token }
      assert_response :unprocessable_entity
      assert_select "h2", @film.title
    end
    post rating_path, params: { rating_film_id: row.id, value: Ratings::Rating::Values::PRETTY_GOOD,
      expression_texts: [ "A thought" ], authenticity_token: token }
    assert_response :see_other
    assert_difference "Ratings::RatingFilm.count", 1 do
      follow_redirect!
      assert_select "h2", @next_film.title
    end
    next_row = Ratings::RatingFilm.find_by!(user_id: row.user_id, film_id: @next_film.id)
    post dismiss_rating_path, params: { rating_film_id: next_row.id, authenticity_token: token }
    follow_redirect!
    assert_select ".ui-empty", I18n.t("ratings.browser.empty")
    assert_equal [ "A thought" ], row.reload.current_rating.rating_expressions.pluck(:text)
  end

  test "registered viewers receive a candidate on direct Ratings navigation" do
    user = Identity::UserRegistered.create!(email_address: "discovery@example.test", password: "long test password",
      password_confirmation: "long test password", email_confirmed_at: Time.current)
    get new_session_path
    post session_path, params: { email_address: user.email_address, password: "long test password", authenticity_token: token }
    assert_redirected_to library_path
    assert_difference "Ratings::RatingFilm.count", 1 do
      get new_rating_path
      assert_select "h2", @film.title
    end
    assert_equal user.id, Ratings::RatingFilm.sole.user_id
  end
end
