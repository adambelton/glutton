require "application_system_test_case"

class DiscardGuestAccountTest < ApplicationSystemTestCase
  test "a guest can cancel or confirm discarding their activity" do
    film = Registry::Film.create!(title: "Guest activity film")
    visit new_rating_path
    click_button I18n.t("identity.entry.try_it_out")
    click_button I18n.t("ratings.onboarding.surprise")
    assert_selector "h2", text: film.title

    guest = Identity::UserGuest.sole
    other_session = Identity::Session.create!(user: guest)
    label = I18n.t("identity.entry.discard_guest")
    discard = find_button(label)
    assert_equal "rgba(180, 35, 24, 1)", discard.style("background-color").fetch("background-color")
    assert_equal "rgba(255, 255, 255, 1)", discard.style("color").fetch("color")
    confirmation = I18n.t("identity.entry.confirm_discard_guest")
    discard.click
    assert_selector "dialog[open]", text: confirmation
    within "dialog[open]" do
      cancel = find_button(I18n.t("identity.entry.cancel_discard_guest"))
      assert_equal cancel, find(":focus")
      cancel.click
    end
    assert_no_selector "dialog[open]"
    assert_selector "h2", text: film.title
    assert Ratings::RatingFilm.exists?(user: guest)

    discard.click
    within("dialog[open]") { click_button label }
    assert_current_path root_path
    assert_selector ".ui-toast", text: I18n.t("identity.entry.guest_discarded")
    assert_no_selector ".guest-banner"
    assert_not Identity::User.exists?(guest.id)
    assert_not Identity::Session.exists?(other_session.id)
    assert_not Ratings::RatingFilm.exists?(user_id: guest.id)
    assert Registry::Film.exists?(film.id)
    visit new_rating_path
    assert_current_path new_session_path
  end
end
