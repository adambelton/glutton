require "application_system_test_case"

class RatingVocabularySystemTest < ApplicationSystemTestCase
  ENGLAND_FLAG = "\u{1F3F4 E0067 E0062 E0065 E006E E0067 E007F}".freeze

  test "previewing and saving a vocabulary preserves an in-progress rating" do
    password = "a long test password"
    user = Identity::UserRegistered.create!(email_address: "vocabulary@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current)
    film = Registry::Film.create!(title: "The Empty Room")
    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: user.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path

    visit new_rating_path(film_id: film.id)
    choose "Not For Me", allow_label_click: true
    find("#journal-tab").click
    fill_in I18n.t("ratings.browser.notes"), with: "I kept waiting for a payoff."
    find("#rating-tab").click

    within(".rating-vocabulary-prompt") do
      assert_selector "button #rating-vocabulary-symbol", exact_text: "🌐"
      click_button "Change rating vocabulary"
    end
    within("#rating-vocabulary-editor") do
      find("summary").send_keys(:enter)
      assert_selector 'button[data-rating-vocabulary-picker-key-param="scouse"] [data-symbol="liver-bird"]'
      click_button "Scouse"
    end
    within("#rating-panel .rating-choices") do
      assert_text "Boss"
      assert_text "Sound"
      assert_text "Not Arsed"
      assert_text "Shite"
    end
    assert_nil user.reload.rating_vocabulary
    click_button I18n.t("identity.settings.cancel")

    assert_no_selector "#rating-vocabulary-editor"
    assert_selector "button #rating-vocabulary-symbol", exact_text: "🌐"
    assert_selector "label", exact_text: "Not For Me"
    click_button "Change rating vocabulary"
    within("#rating-vocabulary-editor") do
      assert_selector "summary", text: "International"
      find("summary").click
      click_button "England"
    end
    assert_selector "#rating-panel .rating-choices", text: "Not My Cup of Tea"
    click_button "Save"

    assert_no_selector "#rating-vocabulary-editor"
    assert_selector "button #rating-vocabulary-symbol", exact_text: ENGLAND_FLAG
    assert_selector "label", exact_text: "Not My Cup of Tea"
    assert_current_path new_rating_path(film_id: film.id)
    assert_equal "england", user.reload.rating_vocabulary
    assert_selector "input[name=value][value='not_for_me']:checked", visible: :all
    find("#journal-tab").click
    assert_field I18n.t("ratings.browser.notes"), with: "I kept waiting for a payoff."
    click_button I18n.t("ratings.browser.save")
    assert_current_path library_path(view: "watched")
    assert_equal "not_for_me", Ratings::Rating.sole.value

    set_viewport(320, 760)
    visit account_settings_path
    assert_selector "#account-rating-vocabulary", text: "England"
    assert_selector "button #rating-vocabulary-symbol", exact_text: ENGLAND_FLAG
    click_button "Change rating vocabulary"
    within("dialog[open]") do
      assert_selector "summary", text: "England"
      assert_text "Not My Cup of Tea"
      find("summary").click
      assert_equal "none", find(".rating-vocabulary-option-list").style("list-style-type").fetch("list-style-type")
      assert_selector 'button[data-rating-vocabulary-picker-key-param="canada"] .rating-vocabulary-symbol', exact_text: "🇨🇦"
      click_button "Scouse"
      assert_selector 'summary [data-symbol="liver-bird"]'
      click_button "Save"
    end
    assert_selector "#account-rating-vocabulary", text: "Scouse"
    bird = find('button #rating-vocabulary-symbol img[data-symbol="liver-bird"]')
    assert page.evaluate_async_script("arguments[0].decode().then(() => arguments[1](true), () => arguments[1](false))", bird)
    assert_no_selector "dialog[open]"
    assert_current_path account_settings_path
  ensure
    reset_viewport
  end

  test "the inline editor keeps the rating choices in place and uses the available action row" do
    password = "a long test password"
    user = Identity::UserRegistered.create!(email_address: "layout-vocabulary@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current)
    film = Registry::Film.create!(title: "The Quiet House")
    Ratings::RatingFilm.create!(user:, film:)
    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: user.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path

    visit new_rating_path
    assert_selector "h2", text: film.title
    [ 1400, 320 ].each { |width| assert_editor_layout(width:) }
  ensure
    reset_viewport
  end

  private

  def assert_editor_layout(width:)
    set_viewport(width, 900)
    trigger = find_button(I18n.t("rating_vocabulary.change"))
    assert_equal I18n.t("rating_vocabulary.change"), trigger["data-tooltip"]
    trigger.hover
    assert_equal "visible", page.evaluate_script("getComputedStyle(arguments[0], '::after').visibility", trigger)
    skip = find_button(I18n.t("ratings.browser.dismiss"))
    watchlist = find_button(I18n.t("library.detail.add_to_watchlist"))
    choices = all("#rating-panel .rating-choice", count: 4)
    before = choices.map { |choice| card_position(choice) }
    skip_position = card_position(skip)
    watchlist_position = card_position(watchlist)
    card = element_rectangle(find(".rating-interface"))
    poster = element_rectangle(find(".rating-film-artwork"))
    actions = element_rectangle(find(".rating-actions"))
    assert_in_delta [ poster.y + poster.height, actions.y + actions.height ].max, card.y + card.height, 1
    trigger.click

    dropdown = find("#rating-vocabulary-editor summary")
    grid = element_rectangle(find("#rating-panel .rating-choices"))
    control = element_rectangle(dropdown)
    assert_in_delta grid.x + grid.width / 2, control.x + control.width / 2, 1
    save = find_button("Save", disabled: true)
    cancel = find_button(I18n.t("identity.settings.cancel"))
    if width == 1400
      assert_equal skip_position, card_position(save)
      assert_equal watchlist_position, card_position(cancel)
    else
      card = element_rectangle(find(".rating-interface"))
      save_rect, cancel_rect = [ save, cancel ].map { |button| element_rectangle(button) }
      assert_in_delta card.x, save_rect.x, 1
      assert_in_delta card.x + card.width, cancel_rect.x + cancel_rect.width, 1
      assert_in_delta save_rect.width, cancel_rect.width, 1
      assert_equal save_rect.y, cancel_rect.y
    end
    assert_equal before, choices.map { |choice| card_position(choice) }

    dropdown.click
    click_button "England"
    long_label = find("#rating-panel .rating-choice-caption span", exact_text: "Not My Cup of Tea")
    lines = page.evaluate_script(<<~JS, long_label)
      ((label) => {
        const text = document.createRange()
        text.selectNodeContents(label)
        return text.getClientRects().length
      })(arguments[0])
    JS
    assert_equal 2, lines if width == 320
    assert_equal before, choices.map { |choice| card_position(choice) }
    cancel.click
    assert_no_selector "#rating-vocabulary-editor"
  end

  def card_position(element)
    card = element_rectangle(find(".rating-interface"))
    rect = element_rectangle(element)
    [ rect.x - card.x, rect.y - card.y, rect.width, rect.height ]
  end
end
