require "application_system_test_case"

require Rails.root.join("test/support/taste_profile_openai_stub")

class TasteProfileTest < ApplicationSystemTestCase
  include TasteProfileOpenaiStub
  test "a superuser follows an inline annotation to its claim and source evidence" do
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
    original_size = page.current_window.size
    page.current_window.resize_to(768, 950)
    assert_selector ".ui-nav a", text: I18n.t("registry.title")
    page.current_window.resize_to(390, 950)
    assert_no_selector ".ui-nav a", text: I18n.t("registry.title")
    navigation = find("select.ui-primary-navigation")
    assert_in_delta 0, navigation.evaluate_script("this.parentElement.clientWidth - this.getBoundingClientRect().width"), 1
    assert_equal library_path, navigation.value
    assert_in_delta 1, find("main h1").evaluate_script("this.getBoundingClientRect().width"), 0.5
    search = find("#library-film-query[placeholder='Add films to library']")
    assert_in_delta 0, search.evaluate_script("this.closest('.ui-page-heading').clientWidth - this.getBoundingClientRect().width"), 1
    navigation.find("option", text: I18n.t("registry.title")).select_option
    assert_current_path registry_root_path
    assert_equal registry_root_path, find("select.ui-primary-navigation").value
    page.current_window.resize_to(768, 950)
    assert_operator find("main h1").evaluate_script("this.getBoundingClientRect().width"), :>, 1
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    within(".ui-nav") { click_link I18n.t("account.title") }
    within(".account-tabs") { click_link I18n.t("account.profile") }
    within(".profile-narrative") do
      assert_text "slowly building dread, [1] prefer body horror that feels personal, [2] and dislike gore without a purpose. [3]"
      click_link I18n.t("account.evidence_marker", number: 2)
    end
    within("#profile-evidence-2:target") do
      assert_text "Prefers personal body horror."
      assert_text "The loss of control ties the transformation to the character."
      assert_text "like a loss of control."
      assert_no_text "The extra gore distracted me."
      find("summary", text: I18n.t("account.view_full_notes")).click
      assert_selector "mark", exact_text: "like a loss of control."
      assert_text "The transformation felt like a loss of control."
      assert_text "The extra gore distracted me."
      click_link I18n.t("account.edit_rating", film: film.title)
    end
    assert_current_path edit_rating_path(film_id: film.id)
  ensure
    page.current_window.resize_to(*original_size) if original_size
  end

  test "a quality row opens with the keyboard and closes when clicked" do
    password = "a long test password"
    user = Identity::UserRegistered.create!(email_address: "profile-chips@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current)
    quality = quality_categories(:tone).qualities.create!(name: "Quiet dread", match_rule: "Silence builds a sense of dread.",
      not_sufficient: "A single quiet moment.")
    film = Registry::Film.create!(title: "Quiet Dread")
    Registry::FilmQuality.create!(film:, quality:)
    rating = Ratings::RatingFilm.create!(user:, film:).submit_rating!(value: "brilliant")
    evaluation = Ratings::RatingQualityEval.create!(rating:, input: [], output: {
      notes: {}, calls: [],
      qualities: { quality.id.to_s => { name: quality.name, match_rule: quality.match_rule, not_sufficient: quality.not_sufficient } },
      decisions: [ { quality_id: quality.id, applicable: false, supporting_rating_ids: [], result_ids: [] } ]
    })
    rating.apply_quality_evaluation!(evaluation:)

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: user.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    within(".ui-nav") { click_link I18n.t("account.title") }
    within(".account-tabs") { click_link I18n.t("account.profile") }

    row = find(".profile-quality-item")
    within row do
      assert_no_text quality.match_rule
      find("summary").send_keys(:space)
      assert_text quality.match_rule
      find("summary").click
      assert_no_text quality.match_rule
    end
  end
end
