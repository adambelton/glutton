require "application_system_test_case"

class ExpressionProfileTest < ApplicationSystemTestCase
  test "a superuser follows an inline annotation to its claim and source evidence" do
    password = "a long test password"
    user = Identity::UserRegistered.create!(email_address: "profile-browser@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true)
    film = Registry::Film.create!(title: "Quiet Dread")
    rating_film = Ratings::RatingFilm.create!(user:, film:)
    rating = rating_film.submit_rating!(value: "brilliant",
      expression_texts: [ "The quiet made it unsettling.", "The transformation felt like a loss of control.", "The extra gore distracted me." ])
    profile = "They enjoy slowly building dread, prefer body horror that feels personal, and dislike gore without a purpose."
    anchors = [ "slowly building dread,", "body horror that feels personal,", "gore without a purpose." ]
    claims = [ "Enjoys quiet dread.", "Prefers personal body horror.", "Dislikes gratuitous gore." ]
    explanations = [ "The expression connects quiet to dread.", "The loss of control ties the transformation to the character.",
      "The viewer described the extra gore as a distraction." ]
    synthesizer = lambda do |**|
      conclusions = rating.rating_expressions.ids.each_with_index.map do |id, index|
        { "anchor" => anchors.fetch(index), "claim" => claims.fetch(index), "explanation" => explanations.fetch(index),
          "expression_ids" => [ id ] }
      end
      { "provider" => "stub", "model" => "stub", "usage" => { "input" => 0, "output" => 0 },
        "profile" => profile, "conclusions" => conclusions }
    end
    Ratings::RefreshExpressionProfile.call(user_id: user.id, synthesizer:, tracer_provider: nil)

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
      assert_text "The transformation felt like a loss of control."
      assert_no_text "The extra gore distracted me."
      click_link I18n.t("account.edit_rating", film: film.title)
    end
    assert_current_path edit_rating_path(film_id: film.id)
  end
end
