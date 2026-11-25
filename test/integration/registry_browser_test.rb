require "test_helper"
require_relative "../support/quality_assessment_sources"

class RegistryBrowserTest < ActionDispatch::IntegrationTest
  include FilmImportSources

  setup do
    @user = registered_user(superuser: true)
    @category = quality_categories(:tone)
    @quality = Registry::Quality.create!(name: "Unsettling <script>quality</script>", quality_category: @category,
      match_rule: "A sustained sense of unease.", not_sufficient: "A single surprise is insufficient.")
    @film = Registry::Film.create!(title: "The <script>film</script>", tmdb_id: 348, release_date: Date.new(1979, 5, 25),
      wikidata_id: "Q1", tmdb_metadata: { "details" => { "overview" => "Stored <script>overview</script>", "runtime" => 117 } },
      wikipedia_context: wikipedia_context(text: "Current source <script>text</script>"))
    Registry::FilmQuality.create!(film: @film, quality: @quality)
    bind_user(@user)
  end

  test "unusable optional TMDB data does not break Registry or shared rating presentation" do
    film = Registry::Film.create!(title: "Raw metadata", tmdb_id: 999,
      tmdb_metadata: { details: { overview: [], poster_path: 123, runtime: "117", genres: "Horror",
        production_companies: [ false, { name: [] } ], production_countries: {}, spoken_languages: [ "English" ] } })
    get admin_film_path(film)
    assert_response :success
    get new_rating_path(film_id: film.id)
    assert_response :success
    assert_select ".poster-placeholder"
    assert_select ".film-synopsis-text", count: 0
    assert_select "h2", "Raw metadata"
  end

  test "every list and detail requires a current superuser before looking for records" do
    cookies.delete("session_id")
    paths.each do |path|
      get path
      assert_redirected_to new_session_path
      assert_not_includes response.body, @film.title
    end
    [ registered_user, Identity::UserGuest.create! ].each do |user|
      bind_user(user)
      (paths + [ admin_film_path(999999999) ]).each do |path|
        get path
        assert_response :forbidden
        assert_select "h1", I18n.t("registry.errors.forbidden.title")
        assert_select "a.record-link", count: 0
        assert_equal "no-store", response.headers["Cache-Control"]
      end
    end
  end

  test "guest expiry and revoked sessions preserve Identity handling" do
    guest = Identity::UserGuest.create!
    bind_user(guest)
    travel (Identity::UserGuest::EXPIRY_DURATION + 1.second) do
      paths.each do |path|
        get path
        assert_redirected_to new_session_path
      end
    end
    bind_user(@user)
    Identity::Session.revoke(id: @authentication.id)
    get admin_film_path(@film)
    assert_redirected_to new_session_path
  end

  test "revocation applies to the same browser on its next request" do
    get admin_film_path(@film)
    assert_response :success
    Identity::AccountAdministration::RevokeSuperuser.call(user_id: @user.id, actor_user_id: @user.id)
    get admin_film_path(@film)
    assert_response :forbidden
    assert Identity::Session.find(@authentication.id).active?
    get root_path
    assert_select "header a[href=?]", admin_path, count: 0
  end

  test "superusers browse escaped records and related links without domain writes or jobs" do
    writes = []
    capture_writes = ->(_name, _start, _finish, _id, payload) { writes << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)\b/i) }
    assert_no_enqueued_jobs do
      ActiveSupport::Notifications.subscribed(capture_writes, "sql.active_record") do
        paths.each do |path|
          get path
          assert_response :success
          assert_select 'meta[name="turbo-cache-control"][content="no-cache"]'
          assert_select "aside.admin-sidebar > a.admin-wordmark:first-child[href=?]", library_path
          assert_select "body.admin-page > main#main-content.admin-content"
          assert_select "header.ui-header, .ui-card, .registry-panel", count: 0
          assert_select "aside.admin-sidebar nav.admin-navigation a[aria-current=location]", count: 1
          assert_select "main form[method=post]", count: 0
          assert_select "script", text: /overview|quality|Current source/, count: 0
          assert_no_match(/translation missing/i, response.body)
          assert_equal "no-store", response.headers["Cache-Control"]
        end
      end
    end
    assert_empty writes
    get library_path
    assert_select "header a[href=?]", admin_path
    get admin_film_path(@film)
    assert_select "main > a.admin-back[href=?] + h1", admin_films_path, text: "#{@film.title} (1979)" do
      assert_select ".film-year", "(1979)"
    end
    assert_select "a.admin-back[href=?]", admin_films_path do
      assert_select "span[aria-hidden=true]", "←"
      assert_select "span", "Back to films"
    end
    assert_select "section[aria-labelledby=film-details-heading]"
    assert_select "a[href=?]", admin_quality_path(@quality), text: @quality.name
    assert_select "a[href=?]", admin_quality_category_path(@category), text: @category.name
    assert_select "summary", I18n.t("registry.context_spoilers")
    assert_select "a[href=?]", @film.wikipedia_context.fetch("revision_url")
    assert_select "a[href=?]", @film.wikipedia_context.fetch("history_url")
    assert_select "a[href=?]", @film.wikipedia_context.fetch("license").fetch("url")
    assert_select "p", I18n.t("registry.no_evidence")
    assert_includes response.body, "Current source &lt;script&gt;text&lt;/script&gt;"
    assert_includes response.body, "Stored &lt;script&gt;overview&lt;/script&gt;"
    get admin_quality_path(@quality)
    assert_select "main > a.admin-back[href=?] + h1", admin_qualities_path, text: @quality.name
    assert_select "p", @quality.match_rule
    assert_select "p", @quality.not_sufficient
    assert_select "a[href=?]", admin_film_path(@film), text: "#{@film.title} (1979)" do
      assert_select ".film-year", "(1979)"
    end
    get admin_quality_category_path(@category)
    assert_select "dd", @category.maximum_qualities.to_s
    assert_select "dd", @category.weight.to_s("F")
    assert_select "a[href=?]", admin_quality_path(@quality)
  end

  test "accepted associations show their saved evidence rather than substituting current source" do
    quality = Registry::Quality.create!(name: "Isolation", quality_category: @category)
    candidate = Registry::Quality.create!(name: "Unaccepted candidate", quality_category: @category)
    saved_context = wikipedia_context(text: "Original evidence <script>quote</script>")
    saved_context["revision_id"] = 19
    saved_context["revision_url"] = "https://en.wikipedia.org/w/index.php?oldid=19"
    evaluation = Registry::FilmQualityEval.create!(film: @film, output: {
      "assessed_at" => Time.current.iso8601, "source" => { "wikipedia_context" => saved_context },
      "definitions" => [], "categories" => [], "question_policy" => "fixture", "selection_policy" => "fixture",
      "evidence_policy" => "fixture", "minimum_support" => 0.6, "model" => "fixture", "support" => { quality.id.to_s => 0.75 },
      "evidence" => { quality.id.to_s => [ "P1" ] }, "selected_quality_ids" => [ quality.id, candidate.id ],
      "input_tokens" => 0, "calculated_cost_usd" => 0, "calls" => [], "call_count" => 0,
      "selection_decisions" => [], "status" => "completed", "usage_complete" => true
    })
    association = Registry::FilmQuality.create!(film: @film, quality:, film_quality_eval: evaluation)
    get admin_film_path(@film)
    assert_response :success
    assert_select ".evidence-content" do
      assert_select "p", I18n.t("registry.support", value: 75)
      assert_select "a[href=?]", saved_context.fetch("revision_url")
      assert_select "a[href=?]", "#evidence-#{association.id}-P1"
      assert_select "article#evidence-#{association.id}-P1 p", "Original evidence <script>quote</script>"
      assert_select "script", count: 0
    end
    assert_select "a[href=?]", admin_quality_path(candidate), count: 0
    assert_select "article#source-P1 p", "Current source <script>text</script>"
  end

  test "support-only assignments show saved support without claiming paragraph evidence" do
    film = Registry::Film.new(tmdb_id: 800003).import!(
      tmdb_data: { title: "Support-only film", release_date: nil, tmdb_metadata: { "details" => {} } },
      wikipedia_context: wikipedia_context(tmdb_id: 800003))
    result = Registry::QualityManagement::AssignInitialFilmQualities.call(film_id: film.id, client: QualityAssessmentSources::Client.new)
    assert_empty result.fetch(:film_quality_eval).output.fetch("evidence")
    get admin_film_path(film)
    assert_response :success
    assert_select ".evidence-content" do
      assert_select "p", I18n.t("registry.support", value: 70)
      assert_select "p", I18n.t("registry.no_paragraph_evidence")
      assert_select "a[href=?]", film.wikipedia_context.fetch("revision_url")
      assert_select "article", count: 0
      assert_select "p", text: I18n.t("registry.no_context"), count: 0
    end
  end

  test "optional fields empty associations missing records and invalid parameters have explicit states" do
    unsourced = Registry::Film.create!(title: "Unsourced")
    get admin_film_path(unsourced)
    assert_response :success
    [ :no_metadata, :no_context, :no_qualities, :source_incomplete ].each do |key|
      assert_includes response.body, I18n.t("registry.#{key}")
    end
    [ admin_film_path(999999999), admin_quality_path("invalid"), admin_quality_category_path("0") ].each do |path|
      get path
      assert_response :not_found
      assert_select "h1", I18n.t("registry.errors.not_found.title")
    end
    [ "0", "-1", "9999999", "abc", [ "1" ], { number: "1" } ].each do |page|
      get admin_films_path, params: { page: }
      assert_response :bad_request
    end
    get admin_films_path(page: 999999)
    assert_response :success
    assert_select ".empty-state", I18n.t("registry.empty")
    get admin_quality_path(Registry::Quality.create!(name: "Unassigned", quality_category: @category))
    assert_select ".empty-state", I18n.t("registry.empty")
  end

  test "stored external URLs cannot introduce executable links" do
    context = wikipedia_context
    context["article_url"] = "javascript:alert(1)"
    context["license"]["url"] = "https://name:password@example.test"
    film = Registry::Film.create!(title: "Legacy context", wikipedia_context: context)
    get admin_film_path(film)
    assert_response :success
    assert_select 'a[href^="javascript:"]', count: 0
    assert_select 'a[href*="password"]', count: 0
    assert_select "article#source-P1"
  end

  test "Registry stylesheet serves its local wordmark font without background imagery" do
    get admin_films_path
    stylesheet = Nokogiri::HTML(response.body).at_css('link[rel="stylesheet"]')["href"]
    get stylesheet
    assert_response :success
    assets = response.body.scan(/url\(["']?([^"')]+)["']?\)/).flatten.select { |path| path.include?("tangerine-regular") }.uniq
    assert_equal 1, assets.size
    assert_no_match(/background-image\s*:/, response.body)
    assets.each do |path|
      get path
      assert_response :success
    end
  end

  test "all catalogue collection searches filter before pagination and can be cleared" do
    11.times do |number|
      Registry::Film.create!(title: "Match film %02d" % number)
      category = Registry::QualityCategory.create!(name: "Match category %02d" % number, maximum_qualities: 1, weight: 1)
      Registry::Quality.create!(name: "Match quality %02d" % number, quality_category: category)
    end
    [ admin_films_path, admin_qualities_path, admin_quality_categories_path ].each do |path|
      get path, params: { q: " MATCH " }
      assert_response :success
      assert_select "tbody tr", count: 10
      assert_select "tbody tr:first-child a", text: /Match .*00/
      assert_select "input[type=search][value=MATCH]"
      assert_select ".collection-search-field > a[aria-label=?][href=?]", "Clear search", path
      next_link = Nokogiri::HTML(response.body).at_css(".admin-page-links a")
      assert_equal "#{path}?page=2&q=MATCH", next_link["href"]
      get next_link["href"]
      assert_select "tbody tr", count: 1
      assert_select "tbody tr a", text: /Match .*10/
      assert_select "a", text: "Next page", count: 0
      assert_select ".admin-page-summary p", "11 results"
      get path
      assert_select "tbody tr", count: 10
      assert_select "a[aria-label=?]:not([hidden])", "Clear search", count: 0
    end

    Registry::Film.create!(title: "Half % of a film")
    get admin_films_path, params: { q: "%" }
    assert_select "tbody tr", count: 1
    assert_select "tbody tr a", "Half % of a film"
    get admin_films_path, params: { q: "_" }
    assert_select "main [role=status]", "No records match your search."
    get admin_films_path, params: { q: [ "Match" ] }
    assert_response :bad_request
  end

  test "catalogue search accepts 254 multibyte characters" do
    query = "é" * 254
    get admin_films_path(q: query)
    assert_response :success
    assert_select "input[type=search][value=?]", query

    get admin_films_path(q: query + "é")
    assert_response :bad_request
  end

  test "lists and related sets have bounded deterministic pagination" do
    25.times { |number| Registry::Film.create!(title: "A film #{number.to_s.rjust(2, '0')}") }
    get admin_films_path
    assert_select "tbody tr", count: 10
    assert_select "tbody tr:first-child a", "A film 00"
    assert_select "a[href=?]", admin_films_path(page: 2)
    get admin_films_path(page: 3)
    assert_select "tbody tr", count: 6
    assert_select "tbody tr a", "#{@film.title} (1979)"
    assert_select "a[href=?]", admin_films_path(page: 2)
    assert_select "a", text: "Next page", count: 0

    26.times do |number|
      quality = Registry::Quality.create!(name: "Quality #{number.to_s.rjust(2, '0')}", quality_category: @category)
      Registry::FilmQuality.create!(film: @film, quality:)
      Registry::FilmQuality.create!(film: Registry::Film.find_by!(title: "A film #{number.to_s.rjust(2, '0')}"), quality: @quality) if number < 25
    end
    get admin_qualities_path
    assert_select "tbody tr", count: 10
    get admin_quality_category_path(@category)
    assert_select "tbody tr", count: 25
    assert_select "a[href=?]", admin_quality_category_path(@category, page: 2)
    get admin_quality_path(@quality)
    assert_select "tbody tr", count: 25
    assert_select "a[href=?]", admin_quality_path(@quality, page: 2)
    get admin_film_path(@film)
    assert_select ".accepted-quality", count: 25
    assert_select "a[href=?]", admin_film_path(@film, page: 2)
    get admin_film_path(@film, page: 2)
    assert_select ".accepted-quality", count: 2
    assert_select "a", text: "Next page", count: 0
  end

  private

  def paths
    [ admin_films_path, admin_quality_categories_path, admin_qualities_path,
      admin_film_path(@film), admin_quality_category_path(@category), admin_quality_path(@quality) ]
  end

  def registered_user(superuser: false)
    Identity::UserRegistered.create!(email_address: "registry-#{Identity::User.count}@example.test", password: "a long test password",
      password_confirmation: "a long test password", email_confirmed_at: Time.current, superuser:)
  end

  def bind_user(user)
    @authentication = Identity::Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: @authentication.id, user_id: user.id } }
    cookies[:session_id] = jar[:session_id]
  end
end
