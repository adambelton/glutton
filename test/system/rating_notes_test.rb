require "application_system_test_case"

class RatingNotesTest < ApplicationSystemTestCase
  test "a viewer saves multiline notes without a separate add step" do
    film = Registry::Film.create!(title: "Browser rating film")
    visit new_rating_path
    click_button I18n.t("identity.entry.try_it_out")
    click_button I18n.t("ratings.onboarding.surprise")
    assert_selector "h2", text: film.title
    save = find_button I18n.t("ratings.browser.save"), disabled: true
    assert_equal({ "cursor" => "not-allowed", "pointer-events" => "auto" }, save.style("cursor", "pointer-events"))
    assert_equal "1", save.style("opacity").fetch("opacity")
    save.hover
    assert page.evaluate_script(<<~JS, save)
      ((button) => {
        const tooltip = getComputedStyle(button, "::after")
        return tooltip.visibility === "visible" && tooltip.opacity === "1" &&
          tooltip.backgroundColor === getComputedStyle(document.body).color
      })(arguments[0])
    JS

    notes = find_field(I18n.t("ratings.browser.notes"))
    notes.send_keys("First line", :enter, "Second line")
    assert_equal "First line\nSecond line", notes.value
    assert_button I18n.t("ratings.browser.save"), disabled: true
    choice = find(".rating-choice", text: I18n.t("ratings.values.brilliant"))
    idle_background = choice.style("background-color")
    choice.hover
    assert_not_equal idle_background, choice.style("background-color")
    choose I18n.t("ratings.values.brilliant"), allow_label_click: true
    save.hover
    assert_equal "hidden", page.evaluate_script("getComputedStyle(arguments[0], '::after').visibility", save)
    click_button I18n.t("ratings.browser.save")
    assert_selector '[role="status"]', text: I18n.t("ratings.browser.saved")
    assert_equal "First line\nSecond line", Ratings::Rating.sole.notes
  end
end
