require "test_helper"

class RatingRevisionBrowserTest < ActionDispatch::IntegrationTest
  setup do
    @forgery = RatingsController.allow_forgery_protection
    RatingsController.allow_forgery_protection = true
    @user = Identity::UserGuest.create!
    bind_user(@user)
    @film = Registry::Film.create!(title: "Revision film")
    @candidate = Ratings::RatingFilm.create!(user: @user, film: @film, suppressed: true, dismissed: true)
    @original = @candidate.submit_rating!(value: Ratings::Rating::Values::BRILLIANT, notes: "  <script>original</script>\nÉerie 👻  ")
  end

  teardown do
    RatingsController.allow_forgery_protection = @forgery
  end

  def bind_user(user)
    authentication = Identity::Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def csrf_token
    Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def revise(token:, **attributes)
    patch rating_path, params: { rating_film_id: @candidate.id, previous_rating_id: @original.id,
      value: Ratings::Rating::Values::PRETTY_GOOD, notes: "New thought", authenticity_token: token }.merge(attributes)
  end

  test "edit reads latest rating and exact escaped expressions without any writes" do
    latest = Ratings::RatingRecording::ReviseRating.call(user_id: @user.id, rating_film_id: @candidate.id,
      previous_rating_id: @original.id, value: Ratings::Rating::Values::NOT_FOR_ME, notes: "  <script>new</script>\n  ")
    assert_no_difference [ "Ratings::RatingFilm.count", "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      get edit_rating_path(film_id: @film.id)
      assert_response :success
      assert_select 'input[name="_method"][value="patch"]'
      assert_select 'input[name="previous_rating_id"][value=?]', latest.id.to_s
      assert_select "input[checked][value=?]", latest.value
      assert_select "textarea#notes", count: 1 do |inputs|
        assert_equal latest.notes, inputs.sole.text
      end
      assert_select "script", text: /new/, count: 0
      assert_select "a[href=?]", new_rating_path
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "replacement preserves original and candidate state without publishing and allows clearing expressions" do
    get edit_rating_path(film_id: @film.id)
    token = csrf_token
    assert_no_difference [ "DomainEvents::DomainEvent.count", "DomainEvents::DomainEventStream.count", "Ratings::RatingFilm.count" ] do
      assert_difference "Ratings::Rating.count", 1 do
        revise(token:, notes: "  Updated\n👻 ", user_id: Identity::UserGuest.create!.id, suppressed: false)
      end
    end
    assert_redirected_to edit_rating_path(film_id: @film.id)
    assert_response :see_other
    follow_redirect!
    assert_select ".ui-toast", count: 0
    latest = @candidate.reload.current_rating
    assert_equal "  Updated\n👻 ", latest.notes
    assert_equal Ratings::Rating::Values::BRILLIANT, @original.reload.value
    assert_equal "  <script>original</script>\nÉerie 👻  ", @original.notes
    assert @candidate.suppressed?
    assert @candidate.dismissed?
    revise(token:, previous_rating_id: latest.id, value: latest.value, notes: " ")
    assert_response :see_other
    assert_nil @candidate.reload.current_rating.notes
    assert_equal 3, @candidate.ratings.count
  end

  test "validation retains original expected id and cannot retarget an intervening revision" do
    get edit_rating_path(film_id: @film.id)
    token = csrf_token
    latest = Ratings::RatingRecording::ReviseRating.call(user_id: @user.id, rating_film_id: @candidate.id,
      previous_rating_id: @original.id, value: Ratings::Rating::Values::GARBAGE)
    assert_no_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      revise(token:, notes: { bad: "shape" })
      assert_response :unprocessable_entity
      assert_select 'input[name="previous_rating_id"][value=?]', @original.id.to_s
      revise(token:)
      assert_response :conflict
      assert_select '[role="alert"]', I18n.t("ratings.errors.stale_rating")
      assert_select "a[href=?]", edit_rating_path(film_id: @film.id)
    end
    get edit_rating_path(film_id: @film.id)
    assert_select 'input[name="previous_rating_id"][value=?]', latest.id.to_s
  end

  test "invalid values and expressions preserve safe input without writing" do
    get edit_rating_path(film_id: @film.id)
    token = csrf_token
    assert_no_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      [ nil, "unknown", [], { bad: "value" } ].each do |value|
        revise(token:, value:, notes: "  Keep <script>this</script>  ")
        assert_response :unprocessable_entity
        assert_select "textarea#notes", "  Keep <script>this</script>  "
        assert_select "script", text: /this/, count: 0
        assert_select 'input[name="previous_rating_id"][value=?]', @original.id.to_s
      end
      revise(token:, notes: "a" * (Ratings::Rating::MAX_NOTES_LENGTH + 1))
      assert_response :unprocessable_entity
      assert_select "input[checked][value=?]", Ratings::Rating::Values::PRETTY_GOOD
      [ [ "text" ], { bad: "text" }, [ { bad: "text" } ] ].each do |notes|
        revise(token:, notes:)
        assert_response :unprocessable_entity
      end
    end
  end

  test "missing malformed stale and replayed previous ids never overwrite" do
    get edit_rating_path(film_id: @film.id)
    token = csrf_token
    assert_no_difference "Ratings::Rating.count" do
      [ nil, "", "0", "-1", "1junk", [], { id: @original.id }, @original.id + 1 ].each do |previous_rating_id|
        revise(token:, previous_rating_id:)
        assert_response :conflict
      end
    end
    revise(token:)
    assert_response :see_other
    assert_no_difference "Ratings::Rating.count" do
      revise(token:)
      assert_response :conflict
    end
  end

  test "missing foreign and unrated candidates are unavailable without admission" do
    get edit_rating_path(film_id: @film.id)
    token = csrf_token
    foreign = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film: Registry::Film.create!(title: "Private film"))
    unrated = Ratings::RatingFilm.create!(user: @user, film: Registry::Film.create!(title: "Unrated"))
    unpresented = Registry::Film.create!(title: "No candidate")
    assert_no_difference [ "Ratings::RatingFilm.count", "Ratings::Rating.count" ] do
      [ nil, "", [], { id: @film.id }, "#{@film.id}junk", foreign.film_id, unpresented.id, Registry::Film.maximum(:id) + 1 ].each do |film_id|
        get edit_rating_path, params: { film_id: }
        assert_response :not_found
        assert_not_includes response.body, "Private film"
      end
      get edit_rating_path(film_id: unrated.film_id)
      assert_response :conflict
      revise(token:, rating_film_id: unrated.id)
      assert_response :conflict
      [ foreign.id, Ratings::RatingFilm.maximum(:id) + 1, nil, [], "#{@candidate.id}junk" ].each do |rating_film_id|
        revise(token:, rating_film_id:)
        assert_response :not_found
      end
    end
  end

  test "registered owners can edit without a post-submission edit link" do
    user = Identity::UserRegistered.create!(email_address: "revision@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    @candidate = Ratings::RatingFilm.create!(user:, film: @film)
    @original = @candidate.submit_rating!(value: Ratings::Rating::Values::BRILLIANT)
    bind_user(user)
    get edit_rating_path(film_id: @film.id)
    token = csrf_token
    revise(token:)
    assert_response :see_other
    film = Registry::Film.create!(title: "<b>Another film</b>")
    row = Ratings::RatingFilm.create!(user:, film:)
    post rating_path, params: { rating_film_id: row.id, value: Ratings::Rating::Values::BRILLIANT, authenticity_token: token }
    assert_redirected_to new_rating_path
    follow_redirect!
    assert_select "a[href=?]", edit_rating_path(film_id: film.id), count: 0
    assert_select "b", count: 0
  end

  test "csrf expired revoked signed out and deleted sessions cannot revise" do
    get edit_rating_path(film_id: @film.id)
    token = csrf_token
    assert_no_difference "Ratings::Rating.count" do
      patch rating_path, params: { rating_film_id: @candidate.id, previous_rating_id: @original.id, value: Ratings::Rating::Values::GARBAGE }
      assert_response :unprocessable_entity
      travel_to @user.created_at + Identity::UserGuest::EXPIRY_DURATION + 1.second do
        patch rating_path, params: { rating_film_id: @candidate.id, previous_rating_id: @original.id, value: Ratings::Rating::Values::GARBAGE, authenticity_token: token }
        assert_response :unauthorized
        get edit_rating_path(film_id: @film.id)
        assert_redirected_to new_session_path
      end
      bind_user(@user)
      Identity::Session.where(user: @user).each { |authentication| Identity::Session.revoke(id: authentication.id) }
      get edit_rating_path(film_id: @film.id)
      assert_redirected_to new_session_path
      cookies.delete(:session_id)
      get edit_rating_path(film_id: @film.id)
      assert_redirected_to new_session_path
      bind_user(@user)
      @user.update_columns(type: "UserDeleted")
      get edit_rating_path(film_id: @film.id)
      assert_response :gone
    end
  end
end
