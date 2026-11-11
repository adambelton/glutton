require "application_system_test_case"

class NotificationTest < ApplicationSystemTestCase
  test "notification banners overlay the viewport without moving the rating card" do
    3.times { |index| Registry::Film.create!(title: "Notification film #{index}") }
    visit new_rating_path
    click_button I18n.t("identity.entry.try_it_out")

    [ [ 1400, 1000 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      assert_selector ".rating-interface"
      before = find(".rating-interface").rect.y
      choose I18n.t("ratings.values.brilliant"), allow_label_click: true
      click_button I18n.t("ratings.browser.save")
      assert_selector '.ui-notifications [role="status"]', text: I18n.t("ratings.browser.saved")
      assert_selector ".ui-notifications .guest-banner"
      assert_in_delta before, find(".rating-interface").rect.y, 1
      notification = find(".ui-toast")
      viewport_width = page.evaluate_script("window.innerWidth")
      assert_in_delta 16, viewport_width - notification.rect.x - notification.rect.width, 1
      assert_operator notification.rect.x, :>=, 16
      click_button I18n.t("ui.dismiss_notification")
      assert_no_selector ".ui-toast"
      assert_in_delta before, find(".rating-interface").rect.y, 1
      assert_selector ".ui-notifications .guest-banner"
    end
  ensure
    page.current_window.resize_to(1400, 1000)
  end

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
