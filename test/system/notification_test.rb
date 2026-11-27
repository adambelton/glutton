require "application_system_test_case"

class NotificationTest < ApplicationSystemTestCase
  test "notification banners overlay the viewport without moving the rating card" do
    3.times { |index| Registry::Film.create!(title: "Notification film #{index}") }
    visit new_rating_path
    click_button I18n.t("identity.entry.try_it_out")
    click_button I18n.t("ratings.onboarding.surprise")

    [ [ 1400, 1000 ], [ 390, 844 ] ].each do |width, height|
      set_viewport(width, height)
      assert_selector ".rating-interface"
      before = element_rectangle(find(".rating-interface")).y
      banner = find("header.ui-header + .guest-banner")
      expected_content_top = width <= 650 ? element_rectangle(banner).y + element_rectangle(banner).height : element_rectangle(banner).y
      assert_in_delta expected_content_top, element_rectangle(find(".ui-content")).y, 1
      assert_equal "center", banner.style("text-align").fetch("text-align")
      choose I18n.t("ratings.values.brilliant"), allow_label_click: true
      click_button I18n.t("ratings.browser.save")
      assert_selector '.ui-notifications [role="status"]', text: I18n.t("ratings.browser.saved")
      assert_selector "header.ui-header + .guest-banner"
      assert_in_delta before, element_rectangle(find(".rating-interface")).y, 1
      notification = find(".ui-toast")
      overlay = find(".ui-notifications")
      assert_equal({ "position" => "fixed", "right" => "16px" }, overlay.style("position", "right"))
      assert_operator element_rectangle(notification).x, :>=, 16
      assert page.evaluate_script("arguments[0].getBoundingClientRect().right <= document.documentElement.clientWidth", notification)
      dismiss = find_button(I18n.t("ui.dismiss_notification"))
      dismiss.hover
      assert_equal "rgb(114, 222, 208)", dismiss.style("color").fetch("color")
      dismiss.click
      assert_no_selector ".ui-toast"
      assert_in_delta before, element_rectangle(find(".rating-interface")).y, 1
      assert_selector "header.ui-header + .guest-banner"
    end
  ensure
    reset_viewport
  end

  test "a notification stays open with keyboard focus and can be dismissed" do
    Registry::Film.create!(title: "Film with notification")
    page.driver.with_playwright_page { |browser_page| browser_page.clock.install }
    visit new_rating_path
    click_button I18n.t("identity.entry.try_it_out")
    click_button I18n.t("ratings.onboarding.surprise")
    choose I18n.t("ratings.values.brilliant"), allow_label_click: true
    click_button I18n.t("ratings.browser.save")

    dismiss = find_button(I18n.t("ui.dismiss_notification"))
    dismiss.send_keys(:shift)
    assert_equal I18n.t("ui.dismiss_notification"), find("button:focus")["aria-label"]
    page.driver.with_playwright_page { |browser_page| browser_page.clock.run_for(5_200) }
    assert_selector '[role="status"]', text: I18n.t("ratings.browser.saved")
    dismiss.send_keys(:enter)
    assert_no_selector '[role="status"]', text: I18n.t("ratings.browser.saved")
  end
end
