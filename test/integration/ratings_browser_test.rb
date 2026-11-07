require "test_helper"

class RatingsBrowserTest < ActionDispatch::IntegrationTest
  setup do
    @forgery = RatingsController.allow_forgery_protection
    RatingsController.allow_forgery_protection = true
    @user = Identity::UserGuest.create!
    bind_user(@user)
    @candidate = candidate("First film", created_at: 2.days.ago)
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

  def candidate(title, **attributes)
    Ratings::RatingFilm.create!(user: @user, film: Registry::Film.create!(title:, release_date: Date.new(1982, 6, 25)), **attributes)
  end

  def csrf
    get new_rating_path
    Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def rate(row = @candidate, **attributes)
    post rating_path, params: { rating_film_id: row.id, value: Ratings::Rating::Values::BRILLIANT, authenticity_token: csrf }.merge(attributes)
  end

  test "source links sit between title and synopsis and use stored identities" do
    overview = ("A film synopsis. " * 40).strip
    film = Registry::Film.create!(title: "Linked film", tmdb_id: 348, release_date: Date.new(1979, 5, 25),
      tmdb_metadata: { details: { overview: overview } },
      wikipedia_context: { page_id: 123, article_url: "javascript:alert(1)" })
    linked = Ratings::RatingFilm.create!(user: @user, film:)
    get new_rating_path(film_id: film.id)
    assert_response :success
    assert_select ".rating-film-info" do
      assert_select "h2", "Linked film (1979)"
      assert_select "h2 + .rating-film-links + .rating-description .rating-synopsis", overview
      assert_select 'a[href="https://www.themoviedb.org/movie/348"]', I18n.t("registry.film_presentation.tmdb")
      assert_select "a[href=?]", "https://en.wikipedia.org/w/index.php?curid=123", text: I18n.t("registry.film_presentation.wikipedia")
      assert_select "a", count: 2
      assert_select "a[rel='noopener noreferrer'][target='_blank']", count: 2
      assert_select ".muted", count: 0
    end
    assert_select 'input[name="rating_film_id"][value=?]', linked.id.to_s
  end

  test "missing and malformed source identities do not render source links" do
    film = Registry::Film.create!(title: "Without sources", wikipedia_context: { page_id: "javascript:alert(1)" })
    Ratings::RatingFilm.create!(user: @user, film:)
    get new_rating_path(film_id: film.id)
    assert_response :success
    assert_select ".rating-film-links a", count: 0
  end

  test "queue excludes ineligible and foreign rows and advances through save dismiss and empty" do
    candidate("Held", held: true, created_at: 4.days.ago)
    candidate("Dismissed", dismissed: true, created_at: 4.days.ago)
    rated = candidate("Rated", created_at: 4.days.ago)
    rated.submit_rating!(value: Ratings::Rating::Values::GARBAGE)
    foreign = candidate("Foreign", user: Identity::UserGuest.create!, created_at: 4.days.ago)
    next_candidate = candidate("Next film")
    get new_rating_path
    assert_select "a[href=?]", new_rating_path
    get new_rating_path
    assert_select "h2", "First film (1982)"
    assert_select "form#rating-form[action=?]", rating_path
    assert_select ".rating-interface .rating-actions" do
      assert_select 'button[type="submit"][form="rating-form"].ui-submit', I18n.t("ratings.browser.save")
      assert_select "form[action=?]", dismiss_rating_path do
        assert_select "button", I18n.t("ratings.browser.dismiss")
      end
    end
    assert_select "form#rating-form form", count: 0
    assert_select 'input[name="rating_film_id"][value=?]', @candidate.id.to_s
    assert_select ".rating-film-info .muted", count: 0
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ], 1 do
      assert_no_difference "Library::LibraryFilm.count" do
        rate(expression_texts: [ "  Atmosphere!\nÉerie 👻  ", "", " \t", "The ending" ], user_id: next_candidate.user_id, held: true)
      end
    end
    assert_response :see_other
    assert_equal [ "  Atmosphere!\nÉerie 👻  ", "The ending" ], @candidate.ratings.sole.rating_expressions.pluck(:text)
    assert_equal Ratings::Events::RATING_SUBMITTED, DomainEvents::DomainEvent.last.name
    follow_redirect!
    assert_select "h2", "Next film (1982)"
    assert_select '[role="status"]', I18n.t("ratings.browser.saved")
    assert_no_difference [ "DomainEvents::DomainEvent.count", "Ratings::Rating.count" ] do
      post dismiss_rating_path, params: { rating_film_id: next_candidate.id, authenticity_token: csrf }
    end
    assert_response :see_other
    assert next_candidate.reload.dismissed?
    follow_redirect!
    assert_select "h2", "Foreign (1982)"
    admitted = Ratings::RatingFilm.where(user: @user).find_by!(film_id: foreign.film_id)
    assert_not_equal foreign.id, admitted.id
    post dismiss_rating_path, params: { rating_film_id: admitted.id, authenticity_token: csrf }
    follow_redirect!
    assert_select "p", I18n.t("ratings.browser.empty")
  end

  test "registered users can save all four choices without expressions" do
    @user = Identity::UserRegistered.create!(email_address: "ratings@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    bind_user(@user)
    Ratings::Rating::Values::ALL.each do |value|
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
    rate(expression_texts: [ text, "a" * (Ratings::RatingExpression::MAX_TEXT_LENGTH + 1) ])
    assert_response :unprocessable_entity
    assert_select "script", text: /alert\(/, count: 0
    assert_select "h2", "#{@candidate.film.title} (1982)"
    assert_select ".expression-items input[type=hidden][value=?]", text
    assert_select "input[checked][value=?]", Ratings::Rating::Values::BRILLIANT
    assert_select '#rating-errors[role="alert"]'
    assert_select 'fieldset[aria-describedby*="rating-errors"]', count: 2
    assert_select 'label[for="expression-draft"]'
    assert_select "textarea[maxlength=?]", Ratings::RatingExpression::MAX_TEXT_LENGTH.to_s, count: 1
    assert_empty @candidate.ratings
  end

  test "malformed missing and oversized input never writes" do
    [ nil, "", "unknown", "x" * 10_000, [], { choice: "brilliant" } ].each do |value|
      assert_no_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
        rate(value:, expression_texts: [ "Keep this" ])
        assert_response :unprocessable_entity
        assert_select ".expression-item .expression-copy", "Keep this"
      end
    end
    [ nil, "text", { text: "text" }, [ { text: "text" } ], Array.new(Ratings::Rating::MAX_EXPRESSIONS + 1, "text") ].each do |expression_texts|
      assert_no_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
        rate(expression_texts:)
        assert_response :unprocessable_entity
      end
    end
  end

  test "unadded drafts block saving and stay in the input until explicitly added or cleared" do
    draft = "  <script>draft</script>\nÉerie 👻  "
    assert_no_difference [ "Ratings::Rating.count", "Ratings::RatingExpression.count", "DomainEvents::DomainEvent.count" ] do
      rate(expression_texts: [ "First thought" ], expression_draft: draft)
      assert_response :unprocessable_entity
      assert_select "#rating-errors", text: /#{Regexp.escape(I18n.t("ratings.browser.unadded_expression"))}/
      assert_select "textarea#expression-draft" do |inputs|
        assert_equal draft, inputs.sole.text
      end
      assert_select '.expression-items input[value="First thought"]', count: 1
      assert_select ".expression-items input", count: 1
      assert_select "script", text: "draft", count: 0
    end
    rate(expression_texts: [ "First thought", draft ], expression_draft: "")
    assert_response :see_other
    assert_equal [ "First thought", draft ], @candidate.reload.current_rating.rating_expressions.pluck(:text)
  end

  test "malformed drafts cannot write and pending input remains recoverable at the list limit" do
    [ { bad: "shape" }, [ "text" ] ].each do |expression_draft|
      assert_no_difference "Ratings::Rating.count" do
        rate(expression_draft:)
        assert_response :unprocessable_entity
      end
    end
    assert_no_difference "Ratings::Rating.count" do
      rate(expression_texts: Array.new(Ratings::Rating::MAX_EXPRESSIONS, "Existing"), expression_draft: "Extra")
      assert_response :unprocessable_entity
      assert_select "textarea#expression-draft", "Extra"
      assert_select ".expression-items input", count: Ratings::Rating::MAX_EXPRESSIONS
    end
    rate(expression_draft: " ")
    assert_response :see_other
    assert_empty @candidate.reload.current_rating.rating_expressions
  end

  test "foreign missing and malformed candidates have the same unavailable response" do
    foreign = candidate("Private title", user: Identity::UserGuest.create!)
    token = csrf
    [ foreign.id, Ratings::RatingFilm.maximum(:id) + 1, "#{@candidate.id}junk" ].each do |id|
      post dismiss_rating_path, params: { rating_film_id: id, authenticity_token: token, user_id: foreign.user_id }
      assert_response :not_found
      assert_select '[role="alert"]', I18n.t("ratings.errors.film_unavailable")
      assert_not_includes response.body, "Private title"
    end
    assert_empty foreign.ratings
    assert_not foreign.reload.dismissed?
  end

  test "duplicates report failure and stale forms may still explicitly rate" do
    token = csrf
    @candidate.update!(held: true, dismissed: true)
    post rating_path, params: { rating_film_id: @candidate.id, value: Ratings::Rating::Values::BRILLIANT, authenticity_token: token }
    assert_response :see_other
    assert @candidate.reload.held?
    assert @candidate.dismissed?
    assert_no_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      rate
      assert_response :conflict
      assert_select '[role="alert"]', I18n.t("ratings.errors.already_rated")
      post dismiss_rating_path, params: { rating_film_id: @candidate.id, authenticity_token: csrf }
      assert_response :conflict
      assert_select '[role="alert"]', I18n.t("ratings.errors.dismissal_unavailable")
    end
  end

  test "expired and revoked sessions cannot write or automatically create a guest" do
    token = csrf
    travel (Identity::UserGuest::EXPIRY_DURATION + 1.second) do
      assert_no_difference [ "Identity::User.count", "Identity::Session.count", "Ratings::RatingFilm.count", "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
        post rating_path, params: { rating_film_id: @candidate.id, value: Ratings::Rating::Values::BRILLIANT, authenticity_token: token }
        assert_response :unauthorized
      end
      assert_no_difference [ "Identity::UserGuest.count", "Identity::Session.count" ] do
        get new_rating_path
        assert_redirected_to new_session_path
      end
    end
    bind_user(@user)
    Identity::Session.where(user: @user).each { |authentication| Identity::Session.revoke(id: authentication.id) }
    assert_no_difference [ "Identity::UserGuest.count", "Identity::Session.count" ] do
      get new_rating_path
      assert_redirected_to new_session_path
    end
    bind_user(@user)
    # Explicit existing-session/deleted-row storage fixture; deletion workflow remains separate.
    @user.update_columns(type: "UserDeleted")
    assert_no_difference [ "Identity::User.count", "Identity::Session.count" ] do
      get new_rating_path
      assert_response :gone
    end
  end

  test "csrf is enforced for both writes and expression parameters are filtered" do
    assert_no_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      post rating_path, params: { rating_film_id: @candidate.id, value: Ratings::Rating::Values::BRILLIANT }
      assert_response :unprocessable_entity
      post dismiss_rating_path, params: { rating_film_id: @candidate.id }
      assert_response :unprocessable_entity
    end
    assert_not @candidate.reload.dismissed?
    filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter("expression_texts" => [ "Private expression" ], "expression_draft" => "Private draft")
    assert_equal "[FILTERED]", filtered["expression_texts"]
    assert_equal "[FILTERED]", filtered["expression_draft"]
  end
end
