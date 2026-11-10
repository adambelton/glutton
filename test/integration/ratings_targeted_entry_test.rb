require "test_helper"

class RatingsTargetedEntryTest < ActionDispatch::IntegrationTest
  setup do
    @controllers = [ RatingsController, SessionsController, GuestSessionsController ]
    @forgery = @controllers.to_h { |controller| [ controller, controller.allow_forgery_protection ] }
    @controllers.each { |controller| controller.allow_forgery_protection = true }
    GuestSessionsController::RATE_LIMIT_STORE.clear
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "Selected <film>", release_date: Date.new(1982, 6, 25))
    bind_user
  end

  teardown do
    @forgery.each { |controller, enabled| controller.allow_forgery_protection = enabled }
  end

  def bind_user
    authentication = Identity::Session.create!(user: @user)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: @user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def csrf_token
    Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def candidate
    Ratings::RatingFilm.find_by!(user: @user, film: @film)
  end

  def rate(token:, **attributes)
    targeted = Nokogiri::HTML(response.body).at_css('input[name="targeted"]')&.[]("value")
    post rating_path, params: { rating_film_id: candidate.id, value: Ratings::Rating::Values::PRETTY_GOOD,
      authenticity_token: token, targeted: }.merge(attributes)
  end

  def assert_targeted_controls
    assert_select 'input[name="targeted"][value="1"]'
    assert_select "form[action=?]", dismiss_rating_path, count: 0
    assert_select "a[href=?]", new_rating_path, text: I18n.t("ratings.browser.continue")
  end

  test "opening admits an unfinished candidate and repeated entry preserves it" do
    assert_difference "Ratings::RatingFilm.count", 1 do
      assert_no_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count", "Identity::User.count", "Identity::Session.count" ] do
        2.times { get new_rating_path(film_id: @film.id); assert_response :success }
      end
    end
    row = candidate
    get new_rating_path
    assert_select "h2", "#{@film.title} (1982)"
    [ -> { }, -> { row.hold! }, -> { row.dismiss! }, -> { row.release_hold! } ].each do |arrange|
      arrange.call
      assert_no_changes -> { row.reload.updated_at } do
        get new_rating_path(film_id: @film.id)
        assert_response :success
      end
    end
    assert_select "h2", "#{@film.title} (1982)"
    assert_select 'input[name="rating_film_id"][value=?]', candidate.id.to_s
    assert_select "form[action=?]", rating_path
    assert_select 'form[action*="dismiss"]', count: 0
    assert_select "a[href=?]", new_rating_path
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "registered user saves selected film with exact expressions ignoring ownership and state tampering" do
    @user = Identity::UserRegistered.create!(email_address: "targeted@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    bind_user
    foreign = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film: @film)
    get new_rating_path(film_id: @film.id)
    assert_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ], 1 do
      rate(token: csrf_token, notes: "  <script>Private</script>  \n\nEnding", user_id: foreign.user_id,
        film_id: Registry::Film.create!(title: "Ignored film").id, held: true, dismissed: true)
    end
    assert_response :see_other
    assert_redirected_to new_rating_path
    rating = Ratings::Rating.last
    assert_equal @user.id, rating.rating_film.user_id
    assert_equal "  <script>Private</script>  \n\nEnding", rating.notes
    assert_not rating.rating_film.held?
    assert_not rating.rating_film.dismissed?
    assert_empty foreign.ratings
    follow_redirect!
    assert_select '[role="status"]', I18n.t("ratings.browser.saved")
  end

  test "validation retains selected film choice and escaped exact expressions without admitting candidate" do
    get new_rating_path(film_id: @film.id)
    text = "  <script>alert('expression')</script>  "
    assert_no_difference [ "Ratings::RatingFilm.count", "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      rate(token: csrf_token, notes: (text += "x" * (Ratings::Rating::MAX_NOTES_LENGTH + 1)))
      assert_response :unprocessable_entity
    end
    assert_select "h2", "#{@film.title} (1982)"
    assert_select 'input[name="rating_film_id"][value=?]', candidate.id.to_s
    assert_select "textarea#notes", text
    assert_select "input[checked][value=?]", Ratings::Rating::Values::PRETTY_GOOD
    assert_select '[aria-describedby*="rating-errors"]', count: 2
    assert_select "script", text: /alert\(/, count: 0
    assert_select 'label[for="notes"]'
    assert_select "form[action=?]", rating_path
    assert_targeted_controls
  end

  test "malformed choice and expression structures preserve the existing candidate" do
    get new_rating_path(film_id: @film.id)
    token = csrf_token
    [ { value: nil }, { value: [ "brilliant" ] }, { notes: { text: "text" } },
      { notes: [ { text: "text" } ] } ].each do |attributes|
      assert_no_difference [ "Ratings::RatingFilm.count", "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
        rate(token:, **attributes)
        assert_response :unprocessable_entity
        assert_targeted_controls
      end
    end
  end

  test "an invalid automatic submission retains dismiss controls" do
    Ratings::RatingFilm.create!(user: @user, film: @film)
    get new_rating_path
    rate(token: csrf_token, value: "invalid")

    assert_response :unprocessable_entity
    assert_select "form[action=?]", dismiss_rating_path
    assert_select 'input[name="targeted"]', count: 0
    assert_select "a[href=?]", new_rating_path, text: I18n.t("ratings.browser.continue"), count: 0
  end

  test "already rated entry and stale duplicate submission fail explicitly" do
    get new_rating_path(film_id: @film.id)
    token = csrf_token
    rate(token:)
    assert_response :see_other
    get new_rating_path(film_id: @film.id)
    assert_response :conflict
    assert_select '[role="alert"]', I18n.t("ratings.errors.already_rated")
    assert_no_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      post rating_path, params: { rating_film_id: candidate.id, value: Ratings::Rating::Values::BRILLIANT, authenticity_token: token }
      assert_response :conflict
    end
  end

  test "guest may submit after hold and dismissal arrive without clearing either flag" do
    get new_rating_path(film_id: @film.id)
    token = csrf_token
    row = candidate
    row.hold!
    row.dismiss!
    post rating_path, params: { rating_film_id: candidate.id, value: Ratings::Rating::Values::GARBAGE, authenticity_token: token }
    assert_response :see_other
    assert row.reload.held?
    assert row.dismissed?
    assert_equal Ratings::Rating::Values::GARBAGE, row.ratings.sole.value
  end

  test "invalid film identity and foreign candidate state do not disclose other users" do
    row = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film: @film, held: true, dismissed: true)
    row.submit_rating!(value: Ratings::Rating::Values::BRILLIANT)
    get new_rating_path(film_id: @film.id)
    token = csrf_token
    assert_response :success
    [ "#{@film.id}junk", Registry::Film.maximum(:id) + 1 ].each do |id|
      get new_rating_path(film_id: id)
      assert_response :not_found
      post rating_path, params: { film_id: id, authenticity_token: token }
      assert_response :not_found
    end
    assert_equal 1, Ratings::RatingFilm.where(user: @user).count
  end

  test "explicit guest entry returns to a selected film without registration" do
    cookies.delete("session_id")
    assert_no_difference [ "Identity::User.count", "Ratings::RatingFilm.count" ] do
      get new_rating_path(film_id: @film.id)
      assert_redirected_to new_session_path
    end
    get new_session_path
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
    assert_difference [ "Identity::UserGuest.count", "Identity::Session.count", "Ratings::RatingFilm.count" ], 1 do
      post guest_session_path, params: { authenticity_token: token }
      assert_redirected_to new_rating_path(film_id: @film.id)
      follow_redirect!
      assert_select "h2", "#{@film.title} (1982)"
    end
    guest = Identity::Session.order(:id).last.user
    rating_film = Ratings::RatingFilm.find_by!(user: guest, film: @film)
    csrf_token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
    assert_difference "Ratings::Rating.count", 1 do
      post rating_path, params: { rating_film_id: rating_film.id, value: Ratings::Rating::Values::BRILLIANT, authenticity_token: csrf_token }
      assert_response :see_other
    end
    assert_equal guest.id, rating_film.reload.user_id
  end

  test "writes and targeted GET never create a guest without explicit entry" do
    get new_rating_path(film_id: @film.id)
    token = csrf_token
    post rating_path, params: { rating_film_id: candidate.id, value: Ratings::Rating::Values::BRILLIANT }
    assert_response :unprocessable_entity
    travel (Identity::UserGuest::EXPIRY_DURATION + 1.second) do
      assert_no_difference [ "Ratings::RatingFilm.count", "Identity::User.count", "Identity::Session.count" ] do
        post rating_path, params: { rating_film_id: candidate.id, value: Ratings::Rating::Values::BRILLIANT, authenticity_token: token }
        assert_response :unauthorized
      end
      assert_no_difference [ "Identity::UserGuest.count", "Identity::Session.count", "Ratings::RatingFilm.count" ] do
        get new_rating_path(film_id: @film.id)
        assert_redirected_to new_session_path
      end
    end
    bind_user
    Identity::Session.where(user: @user).each { |authentication| Identity::Session.revoke(id: authentication.id) }
    assert_no_difference [ "Identity::UserGuest.count", "Identity::Session.count" ] do
      get new_rating_path(film_id: @film.id)
      assert_redirected_to new_session_path
    end
    bind_user
    # Explicit existing-session/deleted-row storage fixture; deletion workflow remains separate.
    @user.update_columns(type: "UserDeleted")
    assert_no_difference [ "Identity::User.count", "Identity::Session.count" ] do
      get new_rating_path(film_id: @film.id)
      assert_response :gone
    end
  end

  test "only omission selects the queue while malformed film IDs are rejected" do
    Ratings::RatingFilm.create!(user: @user, film: @film)
    get new_rating_path
    assert_response :success
    assert_select "h2", "#{@film.title} (1982)"
    [ "", "0", "bad", [ @film.id.to_s ], { id: @film.id } ].each do |film_id|
      get new_rating_path, params: { film_id: }
      assert_response :not_found
    end
    get new_rating_path(film_id: @film.id)
    post rating_path, params: { authenticity_token: csrf_token, value: Ratings::Rating::Values::BRILLIANT }
    assert_response :not_found
    assert_empty Ratings::Rating.all
  end

  test "submission requires an existing owned candidate and cannot admit or recreate one" do
    get new_rating_path
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
    foreign = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film: @film)
    [ nil, foreign.id, foreign.id + 1, "#{foreign.id}junk" ].each do |rating_film_id|
      assert_no_difference [ "Ratings::RatingFilm.count", "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
        post rating_path, params: { targeted: "1", film_id: @film.id, rating_film_id:, value: Ratings::Rating::Values::BRILLIANT, authenticity_token: token }
        assert_response :not_found
      end
    end
    get new_rating_path(film_id: @film.id)
    removed_id = candidate.id
    candidate.destroy!
    post rating_path, params: { rating_film_id: removed_id, value: Ratings::Rating::Values::BRILLIANT, authenticity_token: token }
    assert_response :not_found
    assert_empty Ratings::RatingFilm.where(user: @user)
  end
end
