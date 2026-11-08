require "application_system_test_case"

class LandingInteractionsTest < ApplicationSystemTestCase
  test "theme selection survives navigation and reload" do
    visit root_path
    click_button I18n.t("ui.dark_mode")
    assert_selector 'html[data-theme="dark"]'
    visit new_session_path
    assert_selector 'html[data-theme="dark"]'
    refresh
    assert_selector 'button.theme-toggle[aria-pressed="true"]'
    click_button I18n.t("ui.dark_mode")
    assert_selector 'html[data-theme="light"]'
  end

  test "a visitor can select an example and pause automatic rotation" do
    Registry::Film.create!(tmdb_id: 348, title: "First example")
    Registry::Film.create!(tmdb_id: 1091, title: "Second example")
    visit root_path
    assert_selector "h2", text: "First example"
    click_button I18n.t("identity.entry.demo.select", position: 2, count: 2)
    assert_selector "h2", text: "Second example"
    assert_no_selector "h2", text: "First example"
    click_button I18n.t("identity.entry.demo.pause")
    assert_button I18n.t("identity.entry.demo.resume")

    # Move focus and hover away so the explicit pause is the only reason to stop rotation.
    find("h1").hover.click
    sleep 10.2
    assert_selector "h2", text: "Second example"
    click_button I18n.t("identity.entry.demo.resume")
    assert_button I18n.t("identity.entry.demo.pause")
  end
end
