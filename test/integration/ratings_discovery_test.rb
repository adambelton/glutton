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
    assert_no_difference "Ratings::RatingFilm.count" do
      follow_redirect!
      assert_select "form[method=get][action=?] button", choose_films_rating_path, text: I18n.t("ratings.onboarding.choose")
    end
    assert_difference "Ratings::RatingFilm.count", 1 do
      post surprise_rating_path, params: { authenticity_token: token }
      assert_response :see_other
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
      notes: "A thought", authenticity_token: token }
    assert_response :see_other
    assert_difference "Ratings::RatingFilm.count", 1 do
      follow_redirect!
      assert_select "h2", @next_film.title
    end
    next_row = Ratings::RatingFilm.find_by!(user_id: row.user_id, film_id: @next_film.id)
    post dismiss_rating_path, params: { rating_film_id: next_row.id, authenticity_token: token }
    follow_redirect!
    assert_select ".ui-empty", I18n.t("ratings.browser.empty")
    assert_equal "A thought", row.reload.current_rating.notes
  end

  test "registered viewers receive a candidate on direct Ratings navigation" do
    user = Identity::UserRegistered.create!(email_address: "discovery@example.test", password: "long test password",
      password_confirmation: "long test password", email_confirmed_at: Time.current)
    get new_session_path
    post session_path, params: { email_address: user.email_address, password: "long test password", authenticity_token: token }
    assert_redirected_to library_path
    assert_no_difference "Ratings::RatingFilm.count" do
      get new_rating_path
      assert_select "form[method=get][action=?] button", choose_films_rating_path, text: I18n.t("ratings.onboarding.choose")
    end
  end

  test "confirming a selection queues only the chosen films and a stale form cannot add more" do
    selected = [ @next_film ] + Array.new(4) { |index| Registry::Film.create!(title: "Selected #{index}") }
    open_picker
    page = Nokogiri::HTML(response.body)
    selected_ids = selected.map do |film|
      page.at_css("input[type=checkbox][value='#{film.id}']")["value"]
    end
    authenticity_token = token
    assert_difference "Ratings::RatingFilm.count", 5 do
      post queue_films_rating_path, params: { film_ids: selected_ids + [ selected_ids.first ], authenticity_token: }
      assert_response :see_other
    end
    follow_redirect!
    assert_select "h2", @next_film.title
    assert_equal selected.map(&:id), Ratings::RatingFilm.order(:id).pluck(:film_id)
    assert_no_difference "Ratings::RatingFilm.count" do
      post queue_films_rating_path, params: { film_ids: selected_ids, authenticity_token: }
      assert_response :conflict
      get choose_films_rating_path
      assert_redirected_to new_rating_path
      get new_rating_path
      assert_select "h2", @next_film.title
    end
    row = Ratings::RatingFilm.find_by!(film: @next_film)
    post dismiss_rating_path, params: { rating_film_id: row.id, authenticity_token: token }
    follow_redirect!
    assert_select "h2", selected.second.title
  end

  test "empty malformed and unavailable selections write nothing" do
    valid_ids = [ @film.id, @next_film.id ] + Array.new(2) { |index| Registry::Film.create!(title: "Additional #{index}").id }
    open_picker
    authenticity_token = token
    assert_no_difference "Ratings::RatingFilm.count" do
      [ nil, { film: @film.id }, [ "invalid" ], valid_ids + [ valid_ids.first ] ].each do |film_ids|
        post queue_films_rating_path, params: { film_ids:, authenticity_token: }
        assert_response :unprocessable_entity
      end
      post queue_films_rating_path, params: { film_ids: valid_ids + [ valid_ids.last + 1 ], authenticity_token: }
      assert_response :not_found
      post queue_films_rating_path, params: { film_ids: [ @film.id ] }
      assert_response :unprocessable_entity
    end
  end

  test "an empty catalogue leaves the viewer eligible after Surprise me" do
    @film.destroy!
    @next_film.destroy!
    open_picker
    assert_no_difference "Ratings::RatingFilm.count" do
      post surprise_rating_path, params: { authenticity_token: token }
      assert_response :success
      assert_select ".ui-empty", I18n.t("ratings.browser.empty")
      get new_rating_path
      assert_select "form[method=get][action=?] button", choose_films_rating_path, text: I18n.t("ratings.onboarding.choose")
    end
  end

  private

  def open_picker
    get new_session_path
    post guest_session_path, params: { authenticity_token: token }
    assert_no_difference "Ratings::RatingFilm.count" do
      get choose_films_rating_path
      assert_response :success
    end
  end
end
