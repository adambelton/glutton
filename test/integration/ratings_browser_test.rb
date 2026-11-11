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

  def csrf_token
    Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def rate(row = @candidate, token:, **attributes)
    post rating_path, params: { rating_film_id: row.id, value: Ratings::Rating::Values::BRILLIANT, authenticity_token: token }.merge(attributes)
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
    candidate("Suppressed", suppressed: true, created_at: 4.days.ago)
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
      assert_select 'button[type="submit"][form="rating-form"].ui-submit[disabled]', I18n.t("ratings.browser.save")
      assert_select "form[action=?]", dismiss_rating_path do
        assert_select 'input[name="rating_film_id"][value=?]', @candidate.id.to_s
        assert_select "button", I18n.t("ratings.browser.dismiss")
      end
    end
    assert_select "form#rating-form form", count: 0
    assert_select 'input[name="rating_film_id"][value=?]', @candidate.id.to_s
    assert_select ".rating-film-info .muted", count: 0
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ], 1 do
      assert_no_difference "Library::LibraryFilm.count" do
        rate(token: csrf_token, notes: "  Atmosphere!\nÉerie 👻  \n\nThe ending", user_id: next_candidate.user_id, suppressed: true)
      end
    end
    assert_response :see_other
    assert_equal "  Atmosphere!\nÉerie 👻  \n\nThe ending", @candidate.ratings.sole.notes
    assert_equal Ratings::Events::RATING_SUBMITTED, DomainEvents::DomainEvent.last.name
    follow_redirect!
    assert_select "h2", "Next film (1982)"
    assert_select '[role="status"]', I18n.t("ratings.browser.saved")
    assert_no_difference [ "DomainEvents::DomainEvent.count", "Ratings::Rating.count" ] do
      post dismiss_rating_path, params: { rating_film_id: next_candidate.id, authenticity_token: csrf_token }
    end
    assert_response :see_other
    assert next_candidate.reload.dismissed?
    follow_redirect!
    assert_select "h2", "Foreign (1982)"
    admitted = Ratings::RatingFilm.where(user: @user).find_by!(film_id: foreign.film_id)
    assert_not_equal foreign.id, admitted.id
    post dismiss_rating_path, params: { rating_film_id: admitted.id, authenticity_token: csrf_token }
    follow_redirect!
    assert_select "p", I18n.t("ratings.browser.empty")
  end

  test "registered users can save all four choices without expressions" do
    @user = Identity::UserRegistered.create!(email_address: "ratings@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    bind_user(@user)
    Ratings::Rating::Values::ALL.each do |value|
      row = candidate(value)
      get new_rating_path
      rate(row, token: csrf_token, value:)
      assert_response :see_other
      assert_equal value, row.ratings.sole.value
      assert_nil row.ratings.sole.notes
    end
  end

  test "validation preserves choice and exact escaped expressions with associated errors" do
    get new_rating_path
    token = csrf_token
    @candidate.film.update!(title: "<script>alert('title')</script>")
    text = "  <script>alert('expression')</script>  "
    rate(token:, notes: (text += "a" * (Ratings::Rating::MAX_NOTES_LENGTH + 1)))
    assert_response :unprocessable_entity
    assert_select "script", text: /alert\(/, count: 0
    assert_select "h2", "#{@candidate.film.title} (1982)"
    assert_select "textarea#notes", text
    assert_select "input[checked][value=?]", Ratings::Rating::Values::BRILLIANT
    assert_select '#rating-errors[role="alert"]'
    assert_select '[aria-describedby*="rating-errors"]', count: 2
    assert_select 'label[for="notes"]'
    assert_select "textarea[maxlength=?]", Ratings::Rating::MAX_NOTES_LENGTH.to_s, count: 1
    assert_empty @candidate.ratings
  end

  test "malformed missing and oversized input never writes" do
    get new_rating_path
    token = csrf_token
    [ nil, "", "unknown", "x" * 10_000, [], { choice: "brilliant" } ].each do |value|
      assert_no_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
        rate(token:, value:, notes: "Keep this")
        assert_response :unprocessable_entity
        assert_select "textarea#notes", "Keep this"
      end
    end
    [ [ "text" ], { text: "text" }, [ { text: "text" } ] ].each do |notes|
      assert_no_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
        rate(token:, notes:)
        assert_response :unprocessable_entity
      end
    end
  end

  test "foreign missing and malformed candidates have the same unavailable response" do
    foreign = candidate("Private title", user: Identity::UserGuest.create!)
    get new_rating_path
    token = csrf_token
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
    get new_rating_path
    token = csrf_token
    @candidate.suppress!
    @candidate.dismiss!
    post rating_path, params: { rating_film_id: @candidate.id, value: Ratings::Rating::Values::BRILLIANT, authenticity_token: token }
    assert_response :see_other
    assert @candidate.reload.suppressed?
    assert @candidate.dismissed?
    assert_no_difference [ "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      rate(token:)
      assert_response :conflict
      assert_select '[role="alert"]', I18n.t("ratings.errors.already_rated")
      post dismiss_rating_path, params: { rating_film_id: @candidate.id, authenticity_token: token }
      assert_response :conflict
      assert_select '[role="alert"]', I18n.t("ratings.errors.dismissal_unavailable")
    end
  end

  test "expired and revoked sessions cannot write or automatically create a guest" do
    get new_rating_path
    token = csrf_token
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
    filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter("notes" => "Private notes")
    assert_equal "[FILTERED]", filtered["notes"]
  end
end
