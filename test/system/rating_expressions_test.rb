require "application_system_test_case"

class RatingExpressionsTest < ApplicationSystemTestCase
  test "keyboard entry, removal and draft blocking in the rating form" do
    Registry::Film.create!(title: "Browser rating film")
    visit new_rating_path
    click_button I18n.t("identity.entry.try_it_out")
    assert_selector "h2", text: "Browser rating film"

    draft = find_field(I18n.t("ratings.browser.expression_draft"))
    draft.send_keys("First line", [ :shift, :enter ], "Second line")
    assert_equal "First line\nSecond line", draft.value
    assert_no_button I18n.t("ratings.browser.expression_remove", number: 1)
    draft.send_keys(:enter)
    assert_button I18n.t("ratings.browser.expression_remove", number: 1)
    assert_equal "", draft.value

    draft.send_keys("Remove this thought", :enter)
    click_button I18n.t("ratings.browser.expression_remove", number: 2)
    assert_no_text "Remove this thought"
    choose I18n.t("ratings.values.brilliant"), allow_label_click: true

    draft.send_keys("Unadded thought")
    click_button I18n.t("ratings.browser.save")
    assert_selector "textarea:invalid"
    assert_equal "Unadded thought", draft.value
    assert_empty Ratings::Rating.all

    draft.send_keys(:enter)
    click_button I18n.t("ratings.browser.save")
    assert_selector '[role="status"]', text: I18n.t("ratings.browser.saved")
    assert_equal [ "First line\nSecond line", "Unadded thought" ], Ratings::Rating.sole.rating_expressions.pluck(:text)
  end
end
