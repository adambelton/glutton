require "application_system_test_case"

class NotificationTest < ApplicationSystemTestCase
  test "a notification stays open with keyboard focus and can be dismissed" do
    Registry::Film.create!(title: "Film with notification")
    visit new_rating_path
    click_button I18n.t("identity.entry.try_it_out")
    click_button I18n.t("ratings.browser.dismiss")

    dismiss = find_button(I18n.t("ui.dismiss_notification"))
    dismiss.send_keys(:shift)
    assert_selector "button:focus", text: "×"
    sleep 5.2
    assert_selector '[role="status"]', text: I18n.t("ratings.browser.dismissed")
    dismiss.send_keys(:enter)
    assert_no_selector '[role="status"]', text: I18n.t("ratings.browser.dismissed")
  end
end
