require "application_system_test_case"

class DeleteRegisteredAccountTest < ApplicationSystemTestCase
  test "a registered viewer can cancel or confirm closing their account while retaining activity" do
    password = "a long test password"
    user = Identity::UserRegistered.create!(email_address: "delete@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true)
    other_session = Identity::Session.create!(user:)
    film = Registry::Film.create!(title: "Shared film")
    rating = Ratings::RatingFilm.create!(user:, film:).submit_rating!(value: "brilliant", notes: "My notes")
    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: user.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    within(".ui-nav") { click_link I18n.t("account.title") }
    assert_current_path account_settings_path
    assert_selector "section > h2", exact_text: I18n.t("identity.settings.login_details")

    assert_selector ".account-settings-row", count: 2
    row_positions = all(".account-settings-row").map do |row|
      row.evaluate_script(<<~JS)
        (() => {
          const row = this.getBoundingClientRect()
          const field = this.querySelector(".account-settings-field")
          const label = field.querySelector("strong").getBoundingClientRect()
          const value = field.querySelector("p").getBoundingClientRect()
          const button = this.querySelector("button").getBoundingClientRect()
          return { gap: button.left - Math.max(label.right, value.right), stacked: value.top >= label.bottom, trailing: row.right - button.right, top: row.top }
        })()
      JS
    end
    row_positions.each do |position|
      assert position.fetch("stacked")
      assert_operator position.fetch("gap"), :>, 0
      assert_in_delta 0, position.fetch("trailing"), 1
    end
    assert_operator row_positions.last.fetch("top"), :>, row_positions.first.fetch("top")

    click_button I18n.t("identity.settings.change_email")
    within "dialog[open]" do
      assert_field I18n.t("identity.settings.new_email")
      click_button I18n.t("identity.settings.cancel")
    end
    assert_no_selector "dialog[open]"

    click_button I18n.t("identity.settings.change_password")
    within "dialog[open]" do
      fill_in "change_current_password", with: "incorrect password"
      fill_in "new_password", with: "another long password"
      fill_in "confirm_new_password", with: "another long password"
      click_button I18n.t("identity.settings.change_password")
    end
    within "dialog[open]" do
      assert_text I18n.t("identity.settings.incorrect_current_password")
      click_button I18n.t("identity.settings.cancel")
    end
    assert_no_selector "dialog[open]"

    label = I18n.t("identity.settings.delete_title")
    click_button label
    within "dialog[open]" do
      assert_text I18n.t("identity.settings.delete_description")
      click_button I18n.t("identity.settings.cancel")
    end
    assert_no_selector "dialog[open]"
    assert Identity::UserRegistered.exists?(user.id)

    click_button label
    within("dialog[open]") { click_button label }
    assert_current_path root_path
    assert_selector ".ui-toast", text: I18n.t("identity.settings.deleted")
    closed_account = Identity::UserDeleted.find(user.id)
    assert_nil closed_account.email_address
    assert_nil closed_account.password_digest
    assert_nil closed_account.email_confirmed_at
    assert_not closed_account.superuser?
    assert_not Identity::Session.exists?(user_id: user.id)
    assert_raises(Identity::Errors::AccountDeleted) { Identity::Session.resume(id: other_session.id, user_id: user.id) }
    assert_nil Identity::Authentication::Authenticate.call(email_address: user.email_address, password:)
    assert_equal "My notes", rating.reload.notes
    assert_equal "brilliant", rating.value
    assert Registry::Film.exists?(film.id)
  end
end
