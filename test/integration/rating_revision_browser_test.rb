require "test_helper"

class RatingRevisionBrowserTest < ActionDispatch::IntegrationTest
  setup do
    @forgery = RatingsController.allow_forgery_protection
    RatingsController.allow_forgery_protection = true
    @user = UserGuest.create!
    bind_user(@user)
    @film = Film.create!(title: "Revision film")
    @candidate = RatingFilm.create!(user: @user, film: @film, held: true, dismissed: true)
    @original = @candidate.submit_rating!(value: Rating::Values::BRILLIANT, expression_texts: [ "  <script>original</script>\nÉerie 👻  " ])
  end

  teardown do
    RatingsController.allow_forgery_protection = @forgery
  end

  def bind_user(user)
    authentication = Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def edit
    get edit_rating_path(film_id: @film.id)
    Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def revise(**attributes)
    patch rating_path, params: { rating_film_id: @candidate.id, previous_rating_id: @original.id,
      value: Rating::Values::I_ENJOYED_THAT, expression_texts: [ "New thought" ], authenticity_token: edit }.merge(attributes)
  end

  test "edit reads latest rating and exact escaped expressions without any writes" do
    latest = Ratings::ReviseRating.call(user_id: @user.id, rating_film_id: @candidate.id,
      previous_rating_id: @original.id, value: Rating::Values::NOT_FOR_ME, expression_texts: [ "  <script>new</script>\n  " ])
    assert_no_difference [ "RatingFilm.count", "Rating.count", "RatingExpression.count", "DomainEvent.count" ] do
      edit
      assert_response :success
      assert_select 'input[name="_method"][value="patch"]'
      assert_select 'input[name="previous_rating_id"][value=?]', latest.id.to_s
      assert_select "input[checked][value=?]", latest.value
      assert_select "textarea#expression-0", latest.rating_expressions.sole.text
      assert_select "script", text: /new/, count: 0
      assert_select "a[href=?]", new_rating_path
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "replacement preserves original and candidate state without publishing and allows clearing expressions" do
    assert_no_difference [ "DomainEvent.count", "DomainEventStream.count", "RatingFilm.count" ] do
      assert_difference "Rating.count", 1 do
        revise(expression_texts: [ "  Updated\n👻 ", "", "  " ], user_id: UserGuest.create!.id, held: false)
      end
    end
    assert_redirected_to edit_rating_path(film_id: @film.id)
    assert_response :see_other
    follow_redirect!
    assert_select '[role="status"]', I18n.t("ratings.browser.updated")
    latest = @candidate.reload.current_rating
    assert_equal [ "  Updated\n👻 " ], latest.rating_expressions.pluck(:text)
    assert_equal Rating::Values::BRILLIANT, @original.reload.value
    assert_equal [ "  <script>original</script>\nÉerie 👻  " ], @original.rating_expressions.pluck(:text)
    assert @candidate.held?
    assert @candidate.dismissed?
    revise(previous_rating_id: latest.id, value: latest.value, expression_texts: [ "", " " ])
    assert_response :see_other
    assert_empty @candidate.reload.current_rating.rating_expressions
    assert_equal 3, @candidate.ratings.count
  end

  test "validation retains original expected id and cannot retarget an intervening revision" do
    latest = Ratings::ReviseRating.call(user_id: @user.id, rating_film_id: @candidate.id,
      previous_rating_id: @original.id, value: Rating::Values::GARBAGE)
    assert_no_difference [ "Rating.count", "RatingExpression.count", "DomainEvent.count" ] do
      revise(expression_texts: { bad: "shape" })
      assert_response :unprocessable_entity
      assert_select 'input[name="previous_rating_id"][value=?]', @original.id.to_s
      revise
      assert_response :conflict
      assert_select '[role="alert"]', I18n.t("ratings.errors.stale_rating")
      assert_select "a[href=?]", edit_rating_path(film_id: @film.id)
    end
    edit
    assert_select 'input[name="previous_rating_id"][value=?]', latest.id.to_s
  end

  test "invalid values and expressions preserve safe input without writing" do
    assert_no_difference [ "Rating.count", "RatingExpression.count", "DomainEvent.count" ] do
      [ nil, "unknown", [], { bad: "value" } ].each do |value|
        revise(value:, expression_texts: [ "  Keep <script>this</script>  " ])
        assert_response :unprocessable_entity
        assert_select "textarea#expression-0", "  Keep <script>this</script>  "
        assert_select "script", text: /this/, count: 0
        assert_select 'input[name="previous_rating_id"][value=?]', @original.id.to_s
      end
      revise(expression_texts: [ "a" * (RatingExpression::MAX_TEXT_LENGTH + 1) ])
      assert_response :unprocessable_entity
      assert_select "input[checked][value=?]", Rating::Values::I_ENJOYED_THAT
      [ nil, "text", [ { bad: "text" } ], Array.new(Rating::MAX_EXPRESSIONS + 1, "text") ].each do |expression_texts|
        revise(expression_texts:)
        assert_response :unprocessable_entity
      end
    end
  end

  test "missing malformed stale and replayed previous ids never overwrite" do
    assert_no_difference "Rating.count" do
      [ nil, "", "0", "-1", "1junk", [], { id: @original.id }, @original.id + 1 ].each do |previous_rating_id|
        revise(previous_rating_id:)
        assert_response :conflict
      end
    end
    revise
    assert_response :see_other
    assert_no_difference "Rating.count" do
      revise
      assert_response :conflict
    end
  end

  test "missing foreign and unrated candidates are unavailable without admission" do
    foreign = RatingFilm.create!(user: UserGuest.create!, film: Film.create!(title: "Private film"))
    unrated = RatingFilm.create!(user: @user, film: Film.create!(title: "Unrated"))
    unpresented = Film.create!(title: "No candidate")
    assert_no_difference [ "RatingFilm.count", "Rating.count" ] do
      [ nil, "", [], { id: @film.id }, "#{@film.id}junk", foreign.film_id, unpresented.id, Film.maximum(:id) + 1 ].each do |film_id|
        get edit_rating_path, params: { film_id: }
        assert_response :not_found
        assert_not_includes response.body, "Private film"
      end
      get edit_rating_path(film_id: unrated.film_id)
      assert_response :conflict
      revise(rating_film_id: unrated.id)
      assert_response :conflict
      [ foreign.id, RatingFilm.maximum(:id) + 1, nil, [], "#{@candidate.id}junk" ].each do |rating_film_id|
        revise(rating_film_id:)
        assert_response :not_found
      end
    end
  end

  test "registered owners can edit and first submission offers a film specific edit link" do
    user = UserRegistered.create!(email_address: "revision@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    @candidate.update!(user:)
    bind_user(user)
    revise
    assert_response :see_other
    film = Film.create!(title: "<b>Another film</b>")
    row = RatingFilm.create!(user:, film:)
    post rating_path, params: { rating_film_id: row.id, value: Rating::Values::BRILLIANT, authenticity_token: edit }
    assert_redirected_to new_rating_path
    follow_redirect!
    assert_select "a[href=?]", edit_rating_path(film_id: film.id), text: I18n.t("ratings.browser.edit_saved", title: film.title)
    assert_select "b", count: 0
  end

  test "csrf expired revoked signed out and deleted sessions cannot revise" do
    token = edit
    assert_no_difference "Rating.count" do
      patch rating_path, params: { rating_film_id: @candidate.id, previous_rating_id: @original.id, value: Rating::Values::GARBAGE }
      assert_response :unprocessable_entity
      @user.update!(created_at: UserGuest::EXPIRY_DURATION.ago)
      patch rating_path, params: { rating_film_id: @candidate.id, previous_rating_id: @original.id, value: Rating::Values::GARBAGE, authenticity_token: token }
      assert_response :unauthorized
      get edit_rating_path(film_id: @film.id)
      assert_response :unauthorized
      @user.update!(created_at: Time.current)
      Session.where(user: @user).delete_all
      get edit_rating_path(film_id: @film.id)
      assert_response :unauthorized
      cookies.delete(:session_id)
      get edit_rating_path(film_id: @film.id)
      assert_response :unauthorized
      bind_user(@user)
      @user.update_columns(type: "UserDeleted")
      get edit_rating_path(film_id: @film.id)
      assert_response :gone
    end
  end
end
