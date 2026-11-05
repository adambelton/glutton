require "test_helper"
require_relative "../support/film_import_sources"

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

  test "every list and detail requires a current superuser before looking for records" do
    cookies.delete("session_id")
    paths.each do |path|
      get path
      assert_redirected_to new_session_path
      assert_not_includes response.body, @film.title
    end
    [ registered_user, Identity::UserGuest.create! ].each do |user|
      bind_user(user)
      (paths + [ registry_film_path(999999999) ]).each do |path|
        get path
        assert_response :forbidden
        assert_select "h1", I18n.t("registry.errors.forbidden.title")
        assert_select "a.record-link", count: 0
        assert_equal "no-store", response.headers["Cache-Control"]
      end
    end
  end

  test "guest expiry revoked sessions and deleted accounts preserve Identity handling" do
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
    get registry_film_path(@film)
    assert_redirected_to new_session_path

    # A pre-existing session may outlive its account. This fixture does not implement deletion.
    deleted = Identity::UserDeleted.create!
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: @authentication.id, user_id: deleted.id } }
    cookies[:session_id] = jar[:session_id]
    get registry_film_path(@film)
    assert_response :gone
    assert_select "h1", I18n.t("identity.sessions.deleted_title")
    assert_select "a.record-link", count: 0
  end

  test "revocation applies to the same browser on its next request" do
    get registry_film_path(@film)
    assert_response :success
    Identity::RevokeSuperuser.call(user_id: @user.id, actor_user_id: @user.id)
    get registry_film_path(@film)
    assert_response :forbidden
    assert Identity::Session.find(@authentication.id).active?
    get root_path
    assert_select "a[href=?]", registry_root_path, count: 0
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
          assert_select "a.wordmark", "glutton."
          assert_select 'button[data-controller="theme"][aria-pressed="false"]', I18n.t("registry.dark_mode")
          assert_select "main#registry-content"
          assert_select "form", count: 0
          assert_select "script", text: /overview|quality|Current source/, count: 0
          assert_no_match(/translation missing/i, response.body)
          assert_equal "no-store", response.headers["Cache-Control"]
        end
      end
    end
    assert_empty writes
    get root_path
    assert_select "header a[href=?]", registry_root_path
    get registry_film_path(@film)
    assert_select "h1", @film.title
    assert_select "a[href=?]", registry_quality_path(@quality), text: @quality.name
    assert_select "a[href=?]", registry_quality_category_path(@category), text: @category.name
    assert_select "summary", I18n.t("registry.context_spoilers")
    assert_select "a[href=?]", @film.wikipedia_context.fetch("revision_url")
    assert_select "a[href=?]", @film.wikipedia_context.fetch("history_url")
    assert_select "a[href=?]", @film.wikipedia_context.fetch("license").fetch("url")
    assert_select "p", I18n.t("registry.no_evidence")
    assert_includes response.body, "Current source &lt;script&gt;text&lt;/script&gt;"
    assert_includes response.body, "Stored &lt;script&gt;overview&lt;/script&gt;"
    get registry_quality_path(@quality)
    assert_select "h1", @quality.name
    assert_select "p", @quality.match_rule
    assert_select "p", @quality.not_sufficient
    assert_select "a[href=?]", registry_film_path(@film), text: @film.title
    get registry_quality_category_path(@category)
    assert_select "dd", @category.maximum_qualities.to_s
    assert_select "dd", @category.weight.to_s("F")
    assert_select "a[href=?]", registry_quality_path(@quality)
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
    get registry_film_path(@film)
    assert_response :success
    assert_select ".evidence-content" do
      assert_select "p", I18n.t("registry.support", value: 75)
      assert_select "a[href=?]", saved_context.fetch("revision_url")
      assert_select "a[href=?]", "#evidence-#{association.id}-P1"
      assert_select "article#evidence-#{association.id}-P1 p", "Original evidence <script>quote</script>"
      assert_select "script", count: 0
    end
    assert_select "a[href=?]", registry_quality_path(candidate), count: 0
    assert_select "article#source-P1 p", "Current source <script>text</script>"
  end

  test "optional fields empty associations missing records and invalid parameters have explicit states" do
    unsourced = Registry::Film.create!(title: "Unsourced")
    get registry_film_path(unsourced)
    assert_response :success
    [ :no_metadata, :no_context, :no_qualities, :source_incomplete ].each do |key|
      assert_includes response.body, I18n.t("registry.#{key}")
    end
    [ registry_film_path(999999999), registry_quality_path("invalid"), registry_quality_category_path("0") ].each do |path|
      get path
      assert_response :not_found
      assert_select "h1", I18n.t("registry.errors.not_found.title")
    end
    [ "0", "-1", "9999999", "abc", [ "1" ], { number: "1" } ].each do |page|
      get registry_films_path, params: { page: }
      assert_response :bad_request
    end
    get registry_films_path(page: 999999)
    assert_response :success
    assert_select ".empty-state", I18n.t("registry.empty")
    get registry_quality_path(Registry::Quality.create!(name: "Unassigned", quality_category: @category))
    assert_select ".empty-state", I18n.t("registry.empty")
  end

  test "stored external URLs cannot introduce executable links" do
    context = wikipedia_context
    context["article_url"] = "javascript:alert(1)"
    context["license"]["url"] = "https://name:password@example.test"
    film = Registry::Film.create!(title: "Legacy context", wikipedia_context: context)
    get registry_film_path(film)
    assert_response :success
    assert_select 'a[href^="javascript:"]', count: 0
    assert_select 'a[href*="password"]', count: 0
    assert_select "article#source-P1"
  end

  test "Registry stylesheet serves its local wordmark font without hero imagery" do
    get registry_films_path
    stylesheet = Nokogiri::HTML(response.body).at_css('link[rel="stylesheet"]')["href"]
    get stylesheet
    assert_response :success
    assets = response.body.scan(/url\(["']?([^"')]+)["']?\)/).flatten.select { |path| path.include?("tangerine-regular") }.uniq
    assert_equal 1, assets.size
    assert_no_match(/hero|background-image/, response.body)
    assets.each do |path|
      get path
      assert_response :success
    end
  end

  test "lists and related sets have bounded deterministic pagination" do
    25.times { |number| Registry::Film.create!(title: "A film #{number.to_s.rjust(2, '0')}") }
    get registry_films_path
    assert_select "tbody tr", count: 25
    assert_select "tbody tr:first-child a", "A film 00"
    assert_select "a[href=?]", registry_films_path(page: 2)
    get registry_films_path(page: 2)
    assert_select "tbody tr", count: 1
    assert_select "tbody tr a", @film.title
    assert_select "a[href=?]", registry_films_path(page: 1)
    assert_select "a", text: I18n.t("registry.next"), count: 0

    26.times do |number|
      quality = Registry::Quality.create!(name: "Quality #{number.to_s.rjust(2, '0')}", quality_category: @category)
      Registry::FilmQuality.create!(film: @film, quality:)
      Registry::FilmQuality.create!(film: Registry::Film.find_by!(title: "A film #{number.to_s.rjust(2, '0')}"), quality: @quality) if number < 25
    end
    get registry_qualities_path
    assert_select "tbody tr", count: 25
    get registry_quality_category_path(@category)
    assert_select "tbody tr", count: 25
    assert_select "a[href=?]", registry_quality_category_path(@category, page: 2)
    get registry_quality_path(@quality)
    assert_select "tbody tr", count: 25
    assert_select "a[href=?]", registry_quality_path(@quality, page: 2)
    get registry_film_path(@film)
    assert_select ".accepted-quality", count: 25
    assert_select "a[href=?]", registry_film_path(@film, page: 2)
    get registry_film_path(@film, page: 2)
    assert_select ".accepted-quality", count: 2
    assert_select "a", text: I18n.t("registry.next"), count: 0
  end

  private

  def paths
    [ registry_root_path, registry_films_path, registry_quality_categories_path, registry_qualities_path,
      registry_film_path(@film), registry_quality_category_path(@category), registry_quality_path(@quality) ]
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
