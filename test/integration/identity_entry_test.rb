require "test_helper"

class IdentityEntryTest < ActionDispatch::IntegrationTest
  setup do
    @controllers = [ SessionsController, GuestSessionsController, RegistrationsController, RegistrationConfirmationsController ]
    @forgery = @controllers.to_h { |controller| [ controller, controller.allow_forgery_protection ] }
    @controllers.each { |controller| controller.allow_forgery_protection = true }
    SessionsController::RATE_LIMIT_STORE.clear
    GuestSessionsController::RATE_LIMIT_STORE.clear
    Identity::RegistrationRequests::RATE_LIMIT_STORE.clear
    @film = Registry::Film.create!(title: "Preview <script>film</script>", tmdb_id: 348,
      tmdb_metadata: { details: { poster_path: "/poster.jpg" } }, wikipedia_context: { page_id: 123 })
    @password = "a long password phrase"
  end

  teardown { @forgery.each { |controller, enabled| controller.allow_forgery_protection = enabled } }

  def csrf(path = new_session_path)
    get path
    Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def enter_guest
    post guest_session_path, params: { authenticity_token: csrf }
  end

  def registered_user
    Identity::UserRegistered.create!(email_address: "entry@example.test", password: @password,
      password_confirmation: @password, email_confirmed_at: Time.current)
  end

  def login(user)
    post session_path, params: { email_address: user.email_address, password: @password, authenticity_token: csrf }
  end

  test "the five requested horror examples appear in order without creating personal activity" do
    [ [ 1091, "The Thing" ], [ 948, "Halloween" ], [ 9552, "The Exorcist" ], [ 814, "An American Werewolf in London" ] ].each do |tmdb_id, title|
      Registry::Film.create!(tmdb_id:, title:)
    end
    Registry::Film.create!(tmdb_id: 419430, title: "Get Out")
    assert_no_difference [ "Identity::User.count", "Ratings::RatingFilm.count", "Ratings::Rating.count", "Library::LibraryFilm.count" ] do
      get root_path
      assert_response :success
    end
    panels = Nokogiri::HTML(response.body).css(".demo-frame")
    assert_equal [ @film.title, "The Thing", "Halloween", "The Exorcist", "An American Werewolf in London" ], panels.map { |panel| panel.at_css("h2").text }
    assert_select ".demo-dot", count: 5
    panels.each do |panel|
      assert_includes 2..3, panel.css(".expression-items li").size
    end
    assert_select '.demo-frame input[value="pretty_good"][checked]', count: 2
    assert_select '.demo-frame input[value="i_enjoyed_that"]', count: 0
    assert_select ".demo-frame form", count: 0
  end

  test "the anonymous preview offers explicit entry without creating personal records" do
    assert_no_difference [ "Identity::User.count", "Identity::Session.count", "Ratings::RatingFilm.count" ] do
      get root_path
      assert_response :success
    end
    assert_select "header .ui-account-menu", count: 0
    assert_select "header a[href=?]", new_session_path
    assert_select "header a[href=?]", new_registration_path
    assert_select "header form[action=?]", guest_session_path do
      assert_select "button", I18n.t("identity.entry.try_it_out")
    end
    assert_select ".guest-banner", count: 0
    assert_select 'button[data-controller="theme"][aria-label=?]', I18n.t("ui.dark_mode") do
      assert_select 'span[aria-hidden="true"]'
    end
  end

  test "curated rating controls are readonly and have distinct field groups" do
    Registry::Film.create!(title: "Another film", tmdb_id: 1091)
    get root_path
    assert_response :success
    assert_select ".demo-frame", count: 2
    assert_select ".demo-browser form", count: 0
    assert_select ".demo-controls .demo-dot", count: 2
    assert_select '.demo-controls .demo-dot[aria-current="true"]', count: 1
    assert_select ".demo-controls .demo-rotation", count: 1
    assert_select ".demo-disclaimer, .expression-add", count: 0
    assert_select ".demo-frame .expression-remove[disabled]", count: 5
    assert_select '.demo-browser input[name="rating_film_id"]', count: 0
    assert_select ".demo-browser .rating-choices[disabled]", count: 2
    assert_select ".demo-browser fieldset[disabled] input[checked]", count: 2
    document = Nokogiri::HTML(response.body)
    groups = document.css('.demo-frame input[type="radio"]').map { |node| node["name"] }.uniq
    assert_equal 2, groups.size
    assert_select ".demo-browser textarea[disabled]", count: 2
    assert_select ".demo-browser .expression-item", count: 5
    ids = document.css("[id]").map { |node| node["id"] }
    assert_equal ids.uniq, ids
  end

  test "preview uses safe posters and external source links without trailer actions" do
    Registry::Film.create!(title: "Another film", tmdb_id: 1091, tmdb_metadata: { details: { poster_path: "https://evil.test/poster.jpg" } })
    get root_path
    assert_response :success
    assert_select 'img[src="https://image.tmdb.org/t/p/w500/poster.jpg"]'
    assert_select "h2", @film.title
    assert_select ".poster-placeholder"
    assert_select ".demo-browser .rating-film-links", count: 2
    assert_select '.demo-browser .rating-film-links a[target="_blank"][rel="noopener noreferrer"]', count: 3
    assert_select ".demo-browser .rating-film-links a", text: I18n.t("registry.film_presentation.wikipedia")
    assert_select ".demo-browser .rating-film-links a", text: I18n.t("registry.film_presentation.tmdb")
    assert_select '.demo-browser a[href*="trailer"]', count: 0
  end

  test "protected resource returns after explicit guest entry and root then uses guest default" do
    target = library_path(view: "watched", page: 2)
    assert_no_difference [ "Identity::User.count", "Ratings::RatingFilm.count" ] do
      get target
      assert_redirected_to new_session_path
    end
    assert_difference [ "Identity::UserGuest.count", "Identity::Session.count" ], 1 do
      enter_guest
      assert_redirected_to target
    end
    get root_path
    assert_redirected_to new_rating_path
    follow_redirect!
    assert_select ".guest-banner a[href=?]", new_registration_path
    assert_select "header details", count: 0
    assert_select "header a[href=?]", new_session_path
    assert_select "header a[href=?]", new_registration_path
    assert_select "header form[action=?]", session_path, count: 0
    assert_select "header form[action=?]", guest_session_path, count: 0
    assert_no_difference [ "Identity::User.count", "Identity::Session.count" ] do
      enter_guest
      assert_redirected_to new_rating_path
    end
  end

  test "registered login honors explicit destination but otherwise defaults to Library" do
    user = registered_user
    get new_rating_path
    assert_redirected_to new_session_path
    login(user)
    assert_redirected_to new_rating_path
    get root_path
    assert_redirected_to library_path
    follow_redirect!
    assert_select ".guest-banner", count: 0
    assert_select "header details", count: 0
    assert_select "header a[href=?]", new_session_path, count: 0
    assert_select "header a[href=?]", new_registration_path, count: 0
    assert_select "header form[action=?]", guest_session_path, count: 0
    assert_select "header form[action=?]", session_path do
      assert_select 'input[name="_method"][value="delete"]'
      assert_select "button", I18n.t("ui.log_out")
    end
  end

  test "failed login retains guest alternative and the resource target" do
    get library_path
    post session_path, params: { email_address: "wrong@example.test", password: "wrong", authenticity_token: csrf }
    assert_response :unprocessable_entity
    assert_select "form[action=?]", guest_session_path
    enter_guest
    assert_redirected_to library_path
  end

  test "back to browsing abandons an earlier target and returns to the demo" do
    get root_path
    get library_path
    get new_session_path
    assert_select "a[href=?]", root_path, text: I18n.t("identity.entry.back")
    get root_path
    login(registered_user)
    assert_redirected_to library_path
  end

  test "expired continuation defaults and guest creation requires CSRF" do
    get library_path
    assert_no_difference [ "Identity::User.count", "Identity::Session.count" ] do
      post guest_session_path
      assert_response :unprocessable_entity
    end
    travel 61.minutes do
      enter_guest
      assert_redirected_to new_rating_path
    end
  end

  test "completed registration returns to the requested resource after session rotation" do
    previous_origin = ENV["APP_ORIGIN"]
    ENV["APP_ORIGIN"] = "https://glutton.example.test"
    get library_path(view: "watched")
    post registration_path, params: { authenticity_token: csrf(new_registration_path), registration: {
      email_address: "new-entry@example.test", password: @password, password_confirmation: @password } }
    registration = Identity::PendingRegistration.order(:id).last
    post registration_confirmation_path, params: { token: registration.generate_token_for(:email_confirmation),
      authenticity_token: csrf(new_session_path) }
    assert_redirected_to library_path(view: "watched")
    assert_nil Identity::PendingRegistration.find_by(id: registration.id)
    follow_redirect!
    assert_select ".guest-banner", count: 0
  ensure
    ENV["APP_ORIGIN"] = previous_origin
  end

  test "returned resources retain their owning domain missing and forbidden outcomes" do
    get library_film_path(999999999)
    enter_guest
    assert_redirected_to library_film_path(999999999)
    follow_redirect!
    assert_response :not_found
    delete session_path, params: { authenticity_token: csrf }
    get registry_film_path(@film)
    enter_guest
    assert_redirected_to registry_film_path(@film)
    follow_redirect!
    assert_response :forbidden
  end

  test "query parameters cannot disable route authentication" do
    assert_no_difference [ "Identity::User.count", "Ratings::RatingFilm.count" ] do
      get new_rating_path, params: { identity_required: false }
      assert_redirected_to new_session_path
      get registry_film_path(@film), params: { identity_required: false }
      assert_redirected_to new_session_path
    end
  end

  test "latest protected tab wins and return parameters cannot override browser continuation" do
    get new_rating_path
    get library_path(view: "watched")
    get new_session_path, params: { return_to: "https://evil.test", redirect_to: "/registry" }
    enter_guest
    assert_redirected_to library_path(view: "watched")
  end

  test "unauthenticated writes are not replayed and cannot create an identity" do
    assert_no_difference [ "Identity::User.count", "Ratings::Rating.count", "Ratings::RatingFilm.count" ] do
      post rating_path, params: { authenticity_token: csrf, rating_film_id: -1, value: "brilliant" }
      assert_response :unauthorized
    end
    enter_guest
    assert_redirected_to new_rating_path
  end
end
