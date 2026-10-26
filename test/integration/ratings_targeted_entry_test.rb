require "test_helper"

class RatingsTargetedEntryTest < ActionDispatch::IntegrationTest
  setup do
    @forgery = Ratings::RatingsController.allow_forgery_protection
    Ratings::RatingsController.allow_forgery_protection = true
    @user = UserGuest.create!
    @film = Film.create!(title: "Selected <film>", release_date: Date.new(1982, 6, 25))
    bind_user
  end

  teardown do
    Ratings::RatingsController.allow_forgery_protection = @forgery
  end

  def bind_user
    authentication = Session.create!(user: @user)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: @user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def csrf
    get new_rating_path(film_id: @film.id)
    Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def candidate
    RatingFilm.find_by!(user: @user, film: @film)
  end

  def rate(**attributes)
    token = csrf
    post ratings_path, params: { rating_film_id: candidate.id, value: Rating::Values::I_ENJOYED_THAT, authenticity_token: token }.merge(attributes)
  end

  test "opening admits an unfinished candidate and repeated entry preserves it" do
    assert_difference "RatingFilm.count", 1 do
      assert_no_difference [ "Rating.count", "DomainEvent.count", "User.count", "Session.count" ] do
        2.times { get new_rating_path(film_id: @film.id); assert_response :success }
      end
    end
    row = candidate
    get new_rating_path
    assert_select "h2", @film.title
    [ false, true ].product([ false, true ]).each do |held, dismissed|
      row.update!(held:, dismissed:)
      assert_no_changes -> { row.reload.updated_at } do
        get new_rating_path(film_id: @film.id)
        assert_response :success
      end
    end
    assert_select "h2", @film.title
    assert_select 'input[name="rating_film_id"][value=?]', candidate.id.to_s
    assert_select "p", "Released in 1982"
    assert_select "form[action=?]", ratings_path
    assert_select 'form[action*="dismiss"]', count: 0
    assert_select "a[href=?]", new_rating_path
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "registered user saves selected film with exact expressions ignoring ownership and state tampering" do
    @user = UserRegistered.create!(email_address: "targeted@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    bind_user
    foreign = RatingFilm.create!(user: UserGuest.create!, film: @film)
    assert_difference [ "Rating.count", "DomainEvent.count" ], 1 do
      rate(expression_texts: [ "  <script>Private</script>  ", "", "Ending" ], user_id: foreign.user_id,
        film_id: Film.create!(title: "Ignored film").id, held: true, dismissed: true)
    end
    assert_response :see_other
    assert_redirected_to new_rating_path
    rating = Rating.last
    assert_equal @user.id, rating.rating_film.user_id
    assert_equal [ "  <script>Private</script>  ", "Ending" ], rating.rating_expressions.pluck(:text)
    assert_not rating.rating_film.held?
    assert_not rating.rating_film.dismissed?
    assert_empty foreign.ratings
    follow_redirect!
    assert_select '[role="status"]', I18n.t("ratings.browser.saved")
  end

  test "validation retains selected film choice and escaped exact expressions without admitting candidate" do
    csrf
    text = "  <script>alert('expression')</script>  "
    assert_no_difference [ "RatingFilm.count", "Rating.count", "DomainEvent.count" ] do
      rate(expression_texts: [ text, "x" * (RatingExpression::MAX_TEXT_LENGTH + 1) ])
      assert_response :unprocessable_entity
    end
    assert_select "h2", @film.title
    assert_select 'input[name="rating_film_id"][value=?]', candidate.id.to_s
    assert_select "textarea#expression-0", text: text
    assert_select "input[checked][value=?]", Rating::Values::I_ENJOYED_THAT
    assert_select 'fieldset[aria-describedby*="rating-errors"]', count: 2
    assert_select "script", text: /alert\(/, count: 0
    assert_select "details[open]"
    assert_select 'label[for="expression-0"]'
    assert_select "form[action=?]", ratings_path
  end

  test "malformed choice and expression structures preserve the existing candidate" do
    csrf
    [ { value: nil }, { value: [ "brilliant" ] }, { expression_texts: "text" }, { expression_texts: { text: "text" } },
      { expression_texts: [ { text: "text" } ] }, { expression_texts: Array.new(Rating::MAX_EXPRESSIONS + 1, "text") } ].each do |attributes|
      assert_no_difference [ "RatingFilm.count", "Rating.count", "DomainEvent.count" ] do
        rate(**attributes)
        assert_response :unprocessable_entity
      end
    end
  end

  test "already rated entry and stale duplicate submission fail explicitly" do
    token = csrf
    rate
    assert_response :see_other
    get new_rating_path(film_id: @film.id)
    assert_response :conflict
    assert_select '[role="alert"]', I18n.t("ratings.errors.already_rated")
    assert_no_difference [ "Rating.count", "DomainEvent.count" ] do
      post ratings_path, params: { rating_film_id: candidate.id, value: Rating::Values::BRILLIANT, authenticity_token: token }
      assert_response :conflict
    end
  end

  test "guest may submit after hold and dismissal arrive without clearing either flag" do
    token = csrf
    row = candidate
    row.update!(held: true, dismissed: true)
    post ratings_path, params: { rating_film_id: candidate.id, value: Rating::Values::GARBAGE, authenticity_token: token }
    assert_response :see_other
    assert row.reload.held?
    assert row.dismissed?
    assert_equal Rating::Values::GARBAGE, row.ratings.sole.value
  end

  test "invalid film identity and foreign candidate state do not disclose other users" do
    row = RatingFilm.create!(user: UserGuest.create!, film: @film, held: true, dismissed: true)
    row.submit_rating!(value: Rating::Values::BRILLIANT)
    token = csrf
    assert_response :success
    [ "#{@film.id}junk", Film.maximum(:id) + 1 ].each do |id|
      get new_rating_path(film_id: id)
      assert_response :not_found
      post ratings_path, params: { film_id: id, authenticity_token: token }
      assert_response :not_found
    end
    assert_equal 1, RatingFilm.where(user: @user).count
  end

  test "csrf and signed out expired revoked deleted sessions prevent writes" do
    token = csrf
    post ratings_path, params: { rating_film_id: candidate.id, value: Rating::Values::BRILLIANT }
    assert_response :unprocessable_entity
    @user.update!(created_at: UserGuest::EXPIRY_DURATION.ago)
    assert_no_difference [ "RatingFilm.count", "User.count", "Session.count" ] do
      post ratings_path, params: { rating_film_id: candidate.id, value: Rating::Values::BRILLIANT, authenticity_token: token }
      assert_response :unauthorized
      get new_rating_path(film_id: @film.id)
      assert_response :unauthorized
      assert_select "a[href=?]", new_session_path
    end
    @user.update!(created_at: Time.current)
    bind_user
    Session.where(user: @user).delete_all
    get new_rating_path(film_id: @film.id)
    assert_response :unauthorized
    bind_user
    @user.update_columns(type: "UserDeleted")
    get new_rating_path(film_id: @film.id)
    assert_response :gone
  end

  test "only omission selects the queue while malformed film IDs are rejected" do
    RatingFilm.create!(user: @user, film: @film)
    get new_rating_path
    assert_response :success
    assert_select "h2", @film.title
    [ "", "0", "bad", [ @film.id.to_s ], { id: @film.id } ].each do |film_id|
      get new_rating_path, params: { film_id: }
      assert_response :not_found
    end
    post ratings_path, params: { authenticity_token: csrf, value: Rating::Values::BRILLIANT }
    assert_response :not_found
    assert_empty Rating.all
  end

  test "submission requires an existing owned candidate and cannot admit or recreate one" do
    get new_rating_path
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
    foreign = RatingFilm.create!(user: UserGuest.create!, film: @film)
    [ nil, foreign.id, foreign.id + 1, "#{foreign.id}junk" ].each do |rating_film_id|
      assert_no_difference [ "RatingFilm.count", "Rating.count", "DomainEvent.count" ] do
        post ratings_path, params: { film_id: @film.id, rating_film_id:, value: Rating::Values::BRILLIANT, authenticity_token: token }
        assert_response :not_found
      end
    end
    csrf
    removed_id = candidate.id
    candidate.destroy!
    post ratings_path, params: { rating_film_id: removed_id, value: Rating::Values::BRILLIANT, authenticity_token: token }
    assert_response :not_found
    assert_empty RatingFilm.where(user: @user)
  end
end
