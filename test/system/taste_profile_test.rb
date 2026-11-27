require "application_system_test_case"

require Rails.root.join("test/support/taste_profile_openai_stub")

class TasteProfileTest < ApplicationSystemTestCase
  include TasteProfileOpenaiStub
  test "a superuser reads the full profile without repeated claims or source notes" do
    password = "a long test password"
    user = Identity::UserRegistered.create!(email_address: "profile-browser@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true)
    film = Registry::Film.create!(title: "Quiet Dread")
    rating_film = Ratings::RatingFilm.create!(user:, film:)
    rating = rating_film.submit_rating!(value: "brilliant",
      notes: "The quiet made it unsettling.\n\nThe transformation felt like a loss of control.\n\nThe extra gore distracted me.")
    profile = "They enjoy slowly building dread, prefer body horror that feels personal, and dislike gore without a purpose."
    anchors = [ "slowly building dread,", "body horror that feels personal,", "gore without a purpose." ]
    claims = [ "Enjoys quiet dread.", "Prefers personal body horror.", "Dislikes gratuitous gore." ]
    explanations = [ "The notes connects quiet to dread.", "The loss of control ties the transformation to the character.",
      "The viewer described the extra gore as a distraction." ]
    excerpts = [ "The quiet made it unsettling.", "like a loss of control.", "The extra gore distracted me." ]
    synthesizer = lambda do |**|
      conclusions = anchors.each_index.map do |index|
        { "anchor" => anchors.fetch(index), "claim" => claims.fetch(index), "explanation" => explanations.fetch(index),
          "citations" => [ { "rating_id" => rating.id, "quote" => excerpts.fetch(index) } ] }
      end
      { "provider" => "stub", "model" => "stub", "usage" => { "input" => 0, "output" => 0 },
        "profile" => profile, "conclusions" => conclusions }
    end
    Ratings::TasteProfiling::RefreshTasteProfile.call(user_id: user.id, client: taste_profile_openai_stub(synthesizer), tracer_provider: nil)

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: user.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    set_viewport(768, 950)
    assert_selector ".ui-nav a", text: I18n.t("admin.title")
    set_viewport(390, 950)
    assert_no_selector ".ui-nav a", text: I18n.t("admin.title")
    navigation = find("select.ui-primary-navigation")
    assert_in_delta 0, navigation.evaluate_script("this.parentElement.clientWidth - this.getBoundingClientRect().width"), 1
    assert_equal library_path, navigation.value
    assert_field I18n.t("library.browser.search.watchlist")
    search = find(".ui-page-heading .search-bar")
    assert_in_delta 0, search.evaluate_script("this.closest('.ui-page-heading').clientWidth - this.getBoundingClientRect().width"), 1
    navigation.find("option", text: I18n.t("admin.title")).select_option
    assert_current_path admin_users_path
    within(".admin-navigation") { click_link I18n.t("registry.films") }
    assert_current_path admin_films_path
    assert_selector ".admin-navigation a[aria-current=location]", text: I18n.t("registry.films")
    set_viewport(768, 950)
    assert_selector "main h1.sr-only", text: I18n.t("registry.films")
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    search = element_rectangle(find_field(I18n.t("admin.search.films")))
    modes = element_rectangle(find(".search-bar-modes"))
    assert_in_delta search.x + search.width, modes.x + modes.width, 1
    assert_operator modes.y, :>=, search.y + search.height
    click_link I18n.t("admin.back_to_glutton")
    assert_current_path library_path
    within(".ui-nav") { click_link I18n.t("account.title") }
    within(".account-tabs") { click_link I18n.t("account.profile") }
    within(".profile-narrative") do
      assert_text profile
      assert_no_selector "a"
    end
    assert_no_selector ".profile-evidence-list, .profile-annotation", visible: :all
    assert_no_text "Enjoys quiet dread."
    assert_no_text "The loss of control ties the transformation to the character."
    assert_no_text "The quiet made it unsettling."

  ensure
    reset_viewport
  end

  test "both profiles use expandable quality rows with right-side chevrons" do
    password = "a long test password"
    user = Identity::UserRegistered.create!(email_address: "profile-chips@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true)
    quality = quality_categories(:tone).qualities.create!(name: "Quiet dread", match_rule: "Silence builds a sense of dread.",
      not_sufficient: "A single quiet moment.")
    film = Registry::Film.create!(title: "Quiet Dread")
    Registry::FilmQuality.create!(film:, quality:)
    rating = Ratings::RatingFilm.create!(user:, film:).submit_rating!(value: "brilliant")
    evaluation = Ratings::RatingQualityEval.create!(rating:, input: [], output: {
      notes: {}, calls: [],
      qualities: { quality.id.to_s => { name: quality.name, match_rule: quality.match_rule, not_sufficient: quality.not_sufficient } },
      decisions: [ { quality_id: quality.id, determination: nil, supporting_rating_ids: [], result_ids: [] } ]
    })
    rating.apply_quality_evaluation!(evaluation:)

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: user.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    within(".ui-nav") { click_link I18n.t("account.title") }
    within(".account-tabs") { click_link I18n.t("account.profile") }

    row = find(".profile-quality-item")
    gap = row.evaluate_script("(() => { const name = this.querySelector('.profile-quality-name'); const score = this.querySelector('.profile-quality-score'); const range = document.createRange(); range.selectNodeContents(name); return score.getBoundingClientRect().left - range.getBoundingClientRect().right; })()")
    assert_operator gap, :>=, 0
    assert_operator gap, :<=, 20
    assert_equal "1px", row.find(:xpath, "..").style("border-left-width").fetch("border-left-width")
    assert_quality_expansion(row, quality.match_rule)

    visit glutton_profile_admin_user_path(user.id)
    row = find(".admin-profile-rankings .profile-quality-item")
    borders = row.find(:xpath, "..").style("border-left-width", "border-bottom-width")
    assert_equal "0px", borders.fetch("border-left-width")
    assert_equal "1px", borders.fetch("border-bottom-width")
    assert_quality_expansion(row, quality.match_rule)
  end

  private

  def assert_quality_expansion(row, definition)
    within row do
      summary = find("summary")
      chevron = "getComputedStyle(this, '::after')"
      closed_transform = summary.evaluate_script("#{chevron}.transform")
      refute_equal "none", closed_transform
      assert_operator summary.evaluate_script("parseFloat(#{chevron}.marginInlineStart)"), :>, 0
      assert_no_text definition
      summary.send_keys(:space)
      assert_text definition
      refute_equal closed_transform, summary.evaluate_script("#{chevron}.transform")
      summary.click
      assert_no_text definition
    end
  end
end
