require "test_helper"

class RatingsBrowserTest < ActionDispatch::IntegrationTest
  setup do
    @forgery = Ratings::CandidatesController.allow_forgery_protection
    Ratings::CandidatesController.allow_forgery_protection = true
    @user = UserGuest.create!
    bind_user(@user)
    @candidate = candidate("First film", created_at: 2.days.ago)
  end

  teardown do
    Ratings::CandidatesController.allow_forgery_protection = @forgery
  end

  def bind_user(user)
    authentication = Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def candidate(title, **attributes)
    RatingFilm.create!(user: @user, film: Film.create!(title:, release_date: Date.new(1982, 6, 25)), **attributes)
  end

  def csrf
    get ratings_candidates_path
    Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def rate(row = @candidate, **attributes)
    post rate_ratings_candidate_path(row), params: { value: Rating::Values::BRILLIANT, authenticity_token: csrf }.merge(attributes)
  end

  test "queue excludes ineligible and foreign rows and advances through save dismiss and empty" do
    candidate("Held", held: true, created_at: 4.days.ago)
    candidate("Dismissed", dismissed: true, created_at: 4.days.ago)
    rated = candidate("Rated", created_at: 4.days.ago)
    rated.submit_rating!(value: Rating::Values::GARBAGE)
    candidate("Foreign", user: UserGuest.create!, created_at: 4.days.ago)
    next_candidate = candidate("Next film")
    get root_path
    assert_select "a[href=?]", ratings_candidates_path
    get ratings_candidates_path
    assert_select "h2", "First film"
    assert_select "p", "Released in 1982"
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_difference [ "Rating.count", "DomainEvent.count" ], 1 do
      assert_no_difference "LibraryFilm.count" do
        rate(expression_texts: [ "  Atmosphere!\nÉerie 👻  ", "", " \t", "The ending" ], user_id: next_candidate.user_id, held: true)
      end
    end
    assert_response :see_other
    assert_equal [ "  Atmosphere!\nÉerie 👻  ", "The ending" ], @candidate.ratings.sole.rating_expressions.pluck(:text)
    assert_equal Ratings::Events::RATING_SUBMITTED, DomainEvent.last.name
    follow_redirect!
    assert_select "h2", "Next film"
    assert_select '[role="status"]', I18n.t("ratings.browser.saved")
    assert_no_difference [ "DomainEvent.count", "Rating.count" ] do
      post dismiss_ratings_candidate_path(next_candidate), params: { authenticity_token: csrf }
    end
    assert_response :see_other
    assert next_candidate.reload.dismissed?
    follow_redirect!
    assert_select "p", I18n.t("ratings.browser.empty")
  end

  test "registered users can save all four choices without expressions" do
    @user = UserRegistered.create!(email_address: "ratings@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    bind_user(@user)
    Rating::Values::ALL.each do |value|
      row = candidate(value)
      rate(row, value:)
      assert_response :see_other
      assert_equal value, row.ratings.sole.value
      assert_empty row.ratings.sole.rating_expressions
    end
  end

  test "validation preserves choice and exact escaped expressions with associated errors" do
    @candidate.film.update!(title: "<script>alert('title')</script>")
    text = "  <script>alert('expression')</script>  "
    rate(expression_texts: [ text, "a" * (RatingExpression::MAX_TEXT_LENGTH + 1) ])
    assert_response :unprocessable_entity
    assert_select "script", text: /alert\(/, count: 0
    assert_select "h2", @candidate.film.title
    assert_select "textarea#expression-0", text: text
    assert_select "input[checked][value=?]", Rating::Values::BRILLIANT
    assert_select '#rating-errors[role="alert"]'
    assert_select 'fieldset[aria-describedby*="rating-errors"]', count: 2
    assert_select 'label[for="expression-0"]'
    assert_select "textarea[maxlength=?]", RatingExpression::MAX_TEXT_LENGTH.to_s, count: Rating::MAX_EXPRESSIONS
    assert_empty @candidate.ratings
  end

  test "malformed missing and oversized input never writes" do
    [ nil, "", "unknown", "x" * 10_000, [], { choice: "brilliant" } ].each do |value|
      assert_no_difference [ "Rating.count", "DomainEvent.count" ] do
        rate(value:, expression_texts: [ "Keep this" ])
        assert_response :unprocessable_entity
        assert_select "textarea#expression-0", "Keep this"
      end
    end
    [ nil, "text", { text: "text" }, [ { text: "text" } ], Array.new(Rating::MAX_EXPRESSIONS + 1, "text") ].each do |expression_texts|
      assert_no_difference [ "Rating.count", "DomainEvent.count" ] do
        rate(expression_texts:)
        assert_response :unprocessable_entity
      end
    end
  end

  test "foreign missing and malformed candidates have the same unavailable response" do
    foreign = candidate("Private title", user: UserGuest.create!)
    token = csrf
    [ foreign.id, RatingFilm.maximum(:id) + 1, "#{@candidate.id}junk" ].each do |id|
      [ :rate, :dismiss ].each do |action|
        post public_send("#{action}_ratings_candidate_path", id), params: { value: Rating::Values::BRILLIANT, authenticity_token: token, user_id: foreign.user_id }
        assert_response :not_found
        assert_select '[role="alert"]', I18n.t("ratings.errors.film_unavailable")
        assert_not_includes response.body, "Private title"
      end
    end
    assert_empty foreign.ratings
    assert_not foreign.reload.dismissed?
  end

  test "duplicates report failure and stale forms may still explicitly rate" do
    token = csrf
    @candidate.update!(held: true, dismissed: true)
    post rate_ratings_candidate_path(@candidate), params: { value: Rating::Values::BRILLIANT, authenticity_token: token }
    assert_response :see_other
    assert @candidate.reload.held?
    assert @candidate.dismissed?
    assert_no_difference [ "Rating.count", "DomainEvent.count" ] do
      rate
      assert_response :conflict
      assert_select '[role="alert"]', I18n.t("ratings.errors.already_rated")
      post dismiss_ratings_candidate_path(@candidate), params: { authenticity_token: csrf }
      assert_response :conflict
      assert_select '[role="alert"]', I18n.t("ratings.errors.dismissal_unavailable")
    end
  end

  test "signed out expired revoked and deleted sessions cannot write or create replacement users" do
    token = csrf
    @user.update!(created_at: UserGuest::EXPIRY_DURATION.ago)
    assert_no_difference [ "User.count", "Session.count", "RatingFilm.count", "Rating.count", "DomainEvent.count" ] do
      post rate_ratings_candidate_path(@candidate), params: { value: Rating::Values::BRILLIANT, authenticity_token: token }
      assert_response :unauthorized
      get ratings_candidates_path
      assert_response :unauthorized
      assert_select "a[href=?]", new_session_path
      assert_select "a[href=?]", new_registration_path
    end
    @user.update!(created_at: Time.current)
    bind_user(@user)
    Session.where(user: @user).delete_all
    get ratings_candidates_path
    assert_response :unauthorized
    bind_user(@user)
    @user.update_columns(type: "UserDeleted")
    get ratings_candidates_path
    assert_response :gone
  end

  test "csrf is enforced for both writes and expression parameters are filtered" do
    assert_no_difference [ "Rating.count", "DomainEvent.count" ] do
      post rate_ratings_candidate_path(@candidate), params: { value: Rating::Values::BRILLIANT }
      assert_response :unprocessable_entity
      post dismiss_ratings_candidate_path(@candidate)
      assert_response :unprocessable_entity
    end
    assert_not @candidate.reload.dismissed?
    filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter("expression_texts" => [ "Private expression" ])
    assert_equal "[FILTERED]", filtered["expression_texts"]
  end
end
