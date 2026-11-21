require "test_helper"
require "support/marketing_catalogue"

class IdentityEntryTest < ActionDispatch::IntegrationTest
  include MarketingCatalogue
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

  test "discarding guest activity requires a guest session and CSRF token" do
    delete guest_session_path, params: { authenticity_token: csrf }
    assert_response :unauthorized

    user = registered_user
    login(user)
    delete guest_session_path, params: { authenticity_token: csrf }
    assert_response :forbidden
    assert Identity::UserRegistered.exists?(user.id)

    reset!
    enter_guest
    guest = Identity::UserGuest.sole
    delete guest_session_path
    assert_response :unprocessable_entity
    assert Identity::UserGuest.exists?(guest.id)
  end

  def create_marketing_catalogue(poster_paths: {})
    create_preview_catalogue(except: [ 348 ], poster_paths:)
  end

  test "curated samples render without creating personal activity" do
    create_marketing_catalogue
    assert_no_difference [ "Identity::User.count", "Identity::Session.count", "Ratings::RatingFilm.count", "Ratings::Rating.count",
      "Library::LibraryFilm.count", "Recommendations::RecommendationFilm.count", "Ratings::TasteProfile.count" ] do
      get root_path
      assert_response :success
    end
    document = Nokogiri::HTML(response.body)
    ratings = document.css('[aria-labelledby="ratings-preview-heading"] .demo-frame')
    assert_equal [ @film.title, "The Thing (1982)", "The Substance (2024)" ], ratings.map { |panel| panel.at_css("h2").text }
    recommendations = document.css('[aria-labelledby="recommendations-preview-heading"] .demo-frame')
    assert_equal [ "Ring (1998)", "The Witch (2016)", "Backrooms (2026)" ], recommendations.map { |panel| panel.at_css("h2").text }
    assert_equal [ "91%", "87%", "82%" ], recommendations.map { |panel| panel.at_css(".recommendation-match-value").text }
    assert_select '[aria-labelledby="recommendations-preview-heading"]' do
      assert_select '[role="tooltip"], .recommendation-match[tabindex], .recommendation-match[aria-describedby]', count: 0
    end
    assert_select '[aria-labelledby="ratings-preview-heading"] .demo-dot', count: 3
    assert_select '[aria-labelledby="recommendations-preview-heading"] .demo-dot', count: 3
    assert_select '[aria-labelledby="library-preview-heading"] .demo-dot', count: 0
    assert_select ".library-preview", count: 1
    assert_select '[aria-labelledby="profile-preview-heading"] .demo-controls', count: 0
    assert_select '.demo-frame input[value="pretty_good"][checked]', count: 1
    assert_select '.demo-frame input[value="brilliant"][checked]', count: 2
    assert_select ".demo-frame form", count: 0
  end

  test "the anonymous preview offers explicit entry without creating personal records" do
    assert_no_difference [ "Identity::User.count", "Identity::Session.count", "Ratings::RatingFilm.count" ] do
      get root_path
      assert_response :success
    end
    assert_select "header a.wordmark[href=?]", root_path
    assert_select "header a[href=?]", account_settings_path, count: 0
    assert_select "header a[href=?]", new_session_path
    assert_select "header a[href=?]", new_registration_path
    assert_select "header form[action=?]", guest_session_path do
      assert_select "button", I18n.t("identity.entry.try_it_out")
    end
    assert_select 'head link[rel="icon"][href="/glutton-mark.png?v=2"][type="image/png"]'
    assert_select 'head link[rel="icon"][href="/glutton-mark.svg?v=2"][type="image/svg+xml"]'
    assert_select 'head link[rel="apple-touch-icon"][href="/glutton-mark.png?v=2"]'
    assert_select 'head link[href="/icon.png"], head link[href="/icon.svg"]', count: 0
    assert_select ".guest-banner", count: 0
    assert_select 'button[data-controller="theme"][aria-label=?]', I18n.t("ui.dark_mode") do
      assert_select 'span[aria-hidden="true"]'
    end
  end

  test "curated controls are static with distinct field groups and unique ids" do
    create_marketing_catalogue
    get root_path
    assert_response :success
    assert_select ".demo-frame", count: 6
    assert_select ".marketing-preview a[href], .marketing-preview iframe", count: 0
    assert_select ".marketing-preview form", count: 1
    assert_select '.library-preview-search[disabled] form[method="get"][action=?]', library_tmdb_film_search_path, count: 1
    assert_select '.demo-controls .demo-dot[aria-current="true"]', count: 2
    assert_select ".demo-controls .demo-rotation", count: 0
    assert_select ".demo-frame textarea[readonly]", count: 3
    notes = Nokogiri::HTML(response.body).css(".demo-frame textarea[readonly]").map { |field| field.text.strip }
    assert_operator notes.first.split("\n\n").size, :>=, 3
    assert_equal I18n.t("identity.entry.demo.examples.the_thing.notes"), notes.second
    assert_equal 1, notes.second.lines.size
    assert_select '.demo-browser input[name="rating_film_id"]', count: 0
    assert_select ".demo-browser .rating-choices[disabled]", count: 3
    assert_select ".demo-browser .rating-actions button[disabled]", count: 9
    assert_select ".demo-browser fieldset[disabled] input[checked]", count: 3
    document = Nokogiri::HTML(response.body)
    groups = document.css('.demo-frame input[type="radio"]').map { |node| node["name"] }.uniq
    assert_equal 3, groups.size
    ids = document.css("[id]").map { |node| node["id"] }
    assert_equal ids.uniq, ids
  end

  test "previews retain safe poster and source presentation with static trailer imagery" do
    create_marketing_catalogue(poster_paths: { 1091 => "https://evil.test/poster.jpg" })
    get root_path
    assert_select 'img[src="https://image.tmdb.org/t/p/w500/poster.jpg"]'
    assert_select ".poster-placeholder"
    assert_select 'img[src^="https://evil.test"]', count: 0
    assert_select '[aria-labelledby="ratings-preview-heading"] .rating-film-links', count: 3
    assert_select ".rating-film-link", text: I18n.t("registry.film_presentation.wikipedia")
    assert_select ".rating-film-link", text: I18n.t("registry.film_presentation.tmdb")
    assert_select 'img.recommendation-trailer-still[src="https://i.ytimg.com/vi/97OQ7MQC5Ck/hqdefault.jpg"]'
    assert_select ".recommendation-trailer-still", count: 3
    assert_select '.recommendation-trailer-play[aria-hidden="true"] svg', count: 3
    assert_select ".recommendation-trailer-caption", count: 0
    assert_select ".marketing-preview iframe, .marketing-preview a[href]", count: 0
  end

  test "marketing explains the four features in order using complete static app previews" do
    create_marketing_catalogue
    get root_path
    assert_response :success
    document = Nokogiri::HTML(response.body)
    assert_equal %w[ratings-preview-heading recommendations-preview-heading library-preview-heading profile-preview-heading],
      document.css(".marketing-feature-intro h2").map { |heading| heading["id"] }
    %w[ratings recommendations library profile].each do |feature|
      assert_select "##{feature}-preview-heading", I18n.t("identity.entry.features.#{feature}.title")
    end
    assert_select ".marketing-preview .recommendation-film button[disabled]", count: 9
    assert_select ".preview-disclosure, #preview-explanation, .marketing-preview[aria-describedby]", count: 0
    assert_not_includes response.body, "Illustrative example"
    assert_not_includes response.body, "These examples use fictional ratings and notes."
    assert_select ".marketing-preview .profile-narrative", count: 1
    assert_select ".marketing-preview .profile-quality-item", count: 20
    profile_text = document.at_css(".profile-narrative").text
    assert_includes profile_text, "Quiet does not have to mean uneventful: a change in trust"
    assert_not_includes profile_text, "=>"
    assert_select ".marketing-preview .profile-evidence-list, .marketing-preview .profile-annotation", count: 0
    assert_select ".marketing-preview details.profile-quality-item:not([open])", count: 20
    assert_select ".marketing-preview .profile-quality-item > summary", count: 20
    assert_equal %w[+32 +30 +28 +25 +23 +21 +19 +17 +15 +12 -29 -26 -23 -21 -19 -16 -14 -12 -10 -8],
      document.css(".marketing-preview .profile-quality-score").map(&:text)
    assert_select ".marketing-preview .library-films", count: 2
    collections = document.css('[aria-labelledby="library-preview-heading"] .library-preview-panel').map do |frame|
      frame.css(".library-film h3").map(&:text)
    end
    assert_equal [ "Ring (1998)", "The Witch (2016)", "Backrooms (2026)" ], collections.first
    assert_equal 20, collections.last.size
    assert_includes collections.last, "The Thing (1982)"
    assert_includes collections.last, "The Thing (2011)"
    watched = document.at_css('.library-preview-panel[data-view="watched"]')
    assert_equal %w[brilliant garbage not_for_me pretty_good unrated], watched.css("[data-sample-rating]").map { |node| node["data-sample-rating"] }.uniq.sort
    assert_empty collections.first & collections.last
    assert_select '.library-preview-search[disabled] input[type="search"][name="query"]', count: 1
    assert_select ".marketing-preview .library-tabs button", count: 4
    assert_select ".marketing-preview .library-rating-filters button[value]", count: 5
    assert_select ".marketing-preview .library-pagination", count: 2
    assert_select ".marketing-preview .library-card-actions button[disabled]"
    assert_select ".marketing-preview .library-rating-notes-badge"
    assert_select ".marketing-preview .library-rating-icon[aria-description=?]", I18n.t("library.browser.notes_absent")
    assert_select ".marketing-preview .library-rating-icon[aria-label=?]", I18n.t("library.browser.edit_film_rating", title: "The Thing")
    assert_no_match(/translation missing/i, response.body)
    assert_no_match(/journal entr/i, response.body)
  end

  test "marketing entry actions and FAQ surround the feature demonstrations" do
    get root_path
    document = Nokogiri::HTML(response.body)
    assert_equal %w[header section section section section section section], document.css("main.landing-demo > *").map(&:name)
    assert_select ".demo-intro .preview-actions, .demo-intro form, .demo-intro button, .demo-intro a", count: 0
    %w[ratings recommendations library profile].each do |feature|
      assert_select "[aria-labelledby='#{feature}-preview-heading'] .marketing-feature-intro > p:not(.preview-eyebrow)",
        count: 1, text: I18n.t("identity.entry.features.#{feature}.description")
    end
    assert_select ".demo-entry form[action=?]", guest_session_path
    assert_select ".demo-entry a[href=?]", new_registration_path
    assert_select ".demo-entry a[href=?]", new_session_path, count: 0
    assert_equal [ "Who makes Glutton?", "Is Glutton free?", "Why should I write notes about films?",
      "How does Glutton recommend films?", "Are my ratings and notes private?",
      "Can I change my ratings and notes?", "How can I help make Glutton better?" ], document.css(".marketing-faq summary").map(&:text)
    assert_select ".marketing-faq details:not([open]) > summary", count: 7
    assert_equal "marketing-faq", document.at_css(".demo-entry").previous_element["class"]
    document.css(".marketing-feature").each do |section|
      assert_equal "marketing-preview", section.element_children.last["class"]
    end
    assert_includes document.at_css(".marketing-faq").text, "update your rating and notes in Library"
    assert_no_match(/\bwe(?:'re|'ve|'ll)?\b|\bre-review\b|trying to|hoping to|I want to/i, document.at_css("main").text)
    assert_no_match(/translation missing/i, response.body)
  end

  test "missing catalogue preserves the profile and entry with clear film fallbacks" do
    @film.destroy!
    get root_path
    assert_response :success
    assert_select ".marketing-feature", count: 4
    assert_select ".preview-empty", count: 3
    assert_select ".profile-narrative"
    assert_select ".demo-entry form[action=?]", guest_session_path
  end

  test "recommendation preview uses backdrops and the Glutton placeholder when trailers are missing" do
    backdrop_film = Registry::Film.create!(tmdb_id: 310131, title: "Film with backdrop", tmdb_metadata: { details: { backdrop_path: "/still.jpg" } })
    Registry::Film.create!(tmdb_id: 2671, title: "Film with invalid backdrop", tmdb_metadata: { details: { backdrop_path: "//example.test/still.jpg" } })
    get root_path
    assert_response :success
    assert_select '[aria-labelledby="recommendations-preview-heading"]' do
      assert_select ".recommendation-media.recommendation-backdrop[src=?][alt=?]", "https://image.tmdb.org/t/p/w780/still.jpg",
        I18n.t("recommendations.backdrop_for", title: backdrop_film.title), count: 1
      assert_select '.recommendation-media.recommendation-placeholder[aria-hidden="true"]', count: 1
      assert_select ".recommendation-trailer-still, iframe", count: 0
    end
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
    assert_select "header a.wordmark[href=?]", new_rating_path
    assert_select ".guest-banner a[href=?]", new_registration_path
    assert_select "header select.ui-primary-navigation", count: 1
    assert_select "header a[href=?]", new_session_path
    assert_select "header a[href=?]", new_registration_path
    assert_select "header form[action=?]", session_path, count: 0
    assert_select 'header .ui-auth-links a[href=?] + div > button[aria-haspopup="dialog"]', new_registration_path, text: "Discard"
    assert_select "header dialog form[action=?]", guest_session_path do
      assert_select 'input[name="_method"][value="delete"]'
      assert_select "button", "Discard"
    end
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
    assert_select "header a.wordmark[href=?]", new_rating_path
    assert_select ".guest-banner", count: 0
    assert_select "header select.ui-primary-navigation", count: 1
    assert_select "header a[href=?]", new_session_path, count: 0
    assert_select "header a[href=?]", new_registration_path, count: 0
    assert_select "header form[action=?]", guest_session_path, count: 0
    assert_select "header form[action=?]", session_path, count: 0
    get account_settings_path
    assert_select "main form[action=?]", session_path do
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
    post registration_path, params: { authenticity_token: csrf(new_registration_path), registration: { terms_accepted: "1", terms_version: Identity::TermsOfService.current.version, privacy_notice_version: Identity::PrivacyNotice.current.version,
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
    get edit_rating_path(film_id: 999999999)
    enter_guest
    assert_redirected_to edit_rating_path(film_id: 999999999)
    follow_redirect!
    assert_response :not_found
    delete session_path, params: { authenticity_token: csrf }
    get admin_film_path(@film)
    enter_guest
    assert_redirected_to admin_film_path(@film)
    follow_redirect!
    assert_response :forbidden
  end

  test "query parameters cannot disable route authentication" do
    assert_no_difference [ "Identity::User.count", "Ratings::RatingFilm.count" ] do
      get new_rating_path, params: { identity_required: false }
      assert_redirected_to new_session_path
      get admin_film_path(@film), params: { identity_required: false }
      assert_redirected_to new_session_path
    end
  end

  test "latest protected tab wins and return parameters cannot override browser continuation" do
    get new_rating_path
    get library_path(view: "watched")
    get new_session_path, params: { return_to: "https://evil.test", redirect_to: "/admin" }
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
