require "application_system_test_case"

class CommunityUsernameTest < ApplicationSystemTestCase
  test "a member can correct a username error and save without signing in again" do
    password = "a long test password"
    user = Identity::UserRegistered.create!(email_address: "username-browser@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true)
    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: user.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    within(".ui-nav") { click_link I18n.t("account.title") }
    within(".account-tabs") { click_link I18n.t("community.title") }
    assert_current_path account_community_path

    label = I18n.t("identity.settings.community_username.label")
    submit = I18n.t("identity.settings.community_username.save")
    change = I18n.t("identity.settings.community_username.change")
    cancel = I18n.t("identity.settings.cancel")
    assert_username_actions_align(label, submit)
    fill_in label, with: "Glutton"
    click_button submit

    assert_selector '[role="alert"]', text: "Public username is reserved."
    assert_field label, with: "Glutton"
    assert_nil user.reload.community_username

    fill_in label, with: "Ghoul_13"
    click_button submit

    assert_current_path account_community_path
    assert_no_field label
    assert_selector ".account-settings-field p", exact_text: "Ghoul_13"
    assert_selector ".ui-toast", text: I18n.t("identity.settings.community_username.saved")
    assert_equal "Ghoul_13", user.reload.community_username

    click_button change
    assert_field label, with: "Ghoul_13"
    assert_selector "#community_username:focus"
    field = find_field(label)
    assert_operator field.evaluate_script("this.getBoundingClientRect().width"), :<=, 320
    assert_username_actions_align(label, submit, cancel)
    hint = find("#community_username_hint")
    hint_layout = hint.evaluate_script(<<~JS)
      (() => {
        const field = document.getElementById("community_username")
        const submit = this.closest("form").querySelector("button[type=submit]")
        const bounds = this.getBoundingClientRect()
        return {
          smallerThanField: parseFloat(getComputedStyle(this).fontSize) < parseFloat(getComputedStyle(field).fontSize),
          gapAfterField: bounds.top - field.getBoundingClientRect().bottom,
          gapBeforeSubmit: submit.getBoundingClientRect().top - bounds.bottom
        }
      })()
    JS
    assert hint_layout.fetch("smallerThanField")
    assert_operator hint_layout.fetch("gapAfterField"), :>, 0
    assert_operator hint_layout.fetch("gapAfterField"), :<, hint_layout.fetch("gapBeforeSubmit")

    browser = page.driver.browser
    begin
      browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 780, deviceScaleFactor: 1, mobile: false)
      assert_equal 320, page.evaluate_script("window.innerWidth")
      assert_operator field.evaluate_script("this.getBoundingClientRect().width"), :<, 320
      assert_username_actions_align(label, submit, cancel)
    ensure
      browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    end

    fill_in label, with: "Unsaved_name"
    click_button cancel
    assert_current_path account_community_path
    assert_no_field label
    assert_selector ".account-settings-field p", exact_text: "Ghoul_13"
    assert_equal "Ghoul_13", user.reload.community_username

    click_button change
    fill_in label, with: "Support"
    click_button submit
    assert_selector '[role="alert"]', text: "Public username is reserved."
    assert_field label, with: "Support"
    assert_equal "Ghoul_13", user.reload.community_username

    fill_in label, with: "New_Ghoul"
    click_button submit
    assert_no_field label
    assert_selector ".account-settings-field p", exact_text: "New_Ghoul"
    assert_equal "New_Ghoul", user.reload.community_username
  end

  private

  def assert_username_actions_align(label, *actions)
    field = find_field(label).rect
    buttons = actions.map { |action| find_button(action).rect }

    assert_in_delta field.x, buttons.first.x, 1
    assert_in_delta field.x + field.width, buttons.last.x + buttons.last.width, 1
    buttons.each do |button|
      assert_equal buttons.first.y, button.y
      assert_in_delta buttons.first.width, button.width, 1
      assert_in_delta field.height, button.height, 1
    end
  end
end
