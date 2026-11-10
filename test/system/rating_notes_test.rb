require "application_system_test_case"

class RatingNotesTest < ApplicationSystemTestCase
  test "a viewer saves multiline notes without a separate add step" do
    film = Registry::Film.create!(title: "Browser rating film")
    visit new_rating_path
    click_button I18n.t("identity.entry.try_it_out")
    assert_selector "h2", text: film.title
    save = find_button I18n.t("ratings.browser.save"), disabled: true
    assert_equal({ "cursor" => "not-allowed", "pointer-events" => "auto" }, save.style("cursor", "pointer-events"))

    notes = find_field(I18n.t("ratings.browser.notes"))
    notes.send_keys("First line", :enter, "Second line")
    assert_equal "First line\nSecond line", notes.value
    assert_button I18n.t("ratings.browser.save"), disabled: true
    choose I18n.t("ratings.values.brilliant"), allow_label_click: true
    click_button I18n.t("ratings.browser.save")
    assert_selector '[role="status"]', text: I18n.t("ratings.browser.saved")
    assert_equal "First line\nSecond line", Ratings::Rating.sole.notes
  end
end
