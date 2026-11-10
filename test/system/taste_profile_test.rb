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
    Ratings::RefreshTasteProfile.call(user_id: user.id, client: taste_profile_openai_stub(synthesizer), tracer_provider: nil)

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: user.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    within("header") { click_link I18n.t("account.title") }
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
  end
end
