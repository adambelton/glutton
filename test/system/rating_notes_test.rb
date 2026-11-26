require "application_system_test_case"

class RatingNotesTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ], options: { name: :selenium_classic_scrollbars } do |options|
    options.add_argument("--disable-features=OverlayScrollbar")
  end

  test "an overflowing synopsis opens over the centred rating choices" do
    overview = ("A masked traveller follows an empty road through the woods. " * 42).strip
    film = Registry::Film.create!(title: "Long synopsis", tmdb_metadata: { details: { overview: } })
    visit new_rating_path
    click_button I18n.t("identity.entry.try_it_out")
    click_button I18n.t("ratings.onboarding.surprise")
    assert_selector "h2", text: film.title
    expand = find_button I18n.t("ui.synopsis.expand")

    synopsis = find(".film-synopsis-text")
    choices = find(".rating-choices")
    panel_element = find("#rating-panel")
    panel = panel_element.rect
    gap = panel_element.style("row-gap").fetch("row-gap").to_f
    description = find(".film-synopsis").rect
    collapsed = synopsis.rect
    first_lines = synopsis_lines(synopsis)
    choice_grid = choices.rect
    assert_in_delta 2 * synopsis.style("line-height").fetch("line-height").to_f, collapsed.height, 1
    assert_in_delta collapsed.height, description.height, 1
    assert_operator expand.rect.y, :>=, collapsed.y + collapsed.height
    assert_in_delta description.x + description.width, expand.rect.x + expand.rect.width, 1
    assert_in_delta panel.width, choice_grid.width, 1
    assert_in_delta (description.y + description.height + gap + panel.y + panel.height) / 2.0, choice_grid.y + choice_grid.height / 2.0, 1
    assert_selector ".rating-choice", count: 4
    choice = choices.find(".rating-choice", text: I18n.t("ratings.values.brilliant"))
    assert_in_delta 56, choice.rect.height, 1
    assert_operator find(".rating-actions").rect.y - (choice_grid.y + choice_grid.height), :>=, 36
    label = choice.find("label")
    icon = label.find("svg").rect
    caption = label.find("span").rect
    assert_operator icon.x + icon.width, :<, caption.x
    assert_in_delta icon.y + icon.height / 2.0, caption.y + caption.height / 2.0, 1

    click_button I18n.t("ui.synopsis.expand")
    collapse = find_button I18n.t("ui.synopsis.collapse")
    assert_equal "true", collapse["aria-expanded"]
    expanded = synopsis.rect
    assert page.evaluate_script("arguments[0].scrollHeight > arguments[0].clientHeight", synopsis)
    assert_equal first_lines, synopsis_lines(synopsis)
    assert_operator expanded.y + expanded.height, :>, choice_grid.y
    assert_in_delta expanded.y + expanded.height, collapse.rect.y, 1
    assert_in_delta expanded.x + expanded.width, collapse.rect.x + collapse.rect.width, 1
    assert_equal choice_grid, choices.rect

    synopsis.send_keys(:escape)
    expand = find_button I18n.t("ui.synopsis.expand")
    assert_equal expand, page.evaluate_script("document.activeElement")
    assert_equal collapsed, synopsis.rect
    assert_equal choice_grid, choices.rect

    short_film = Registry::Film.create!(title: "Short synopsis", tmdb_metadata: { details: { overview: "A traveller gets lost." } })
    choose I18n.t("ratings.values.brilliant"), allow_label_click: true
    click_button I18n.t("ratings.browser.save")
    assert_selector "h2", text: short_film.title
    assert_selector ".film-synopsis[data-ready]"
    assert_no_button I18n.t("ui.synopsis.expand")
  end

  test "a viewer keeps and saves a rating and notes across panel switches" do
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

    rating_tab = find('[role="tab"]', text: I18n.t("ratings.browser.panels.rating"))
    assert_equal "true", rating_tab["aria-selected"]
    header = find(".rating-film-header").rect
    title = find(".rating-film-header h2").rect
    assert_operator rating_tab.rect.x, :>=, title.x + title.width
    assert_in_delta header.y + header.height, rating_tab.rect.y + rating_tab.rect.height, 1
    assert_no_field I18n.t("ratings.browser.notes")
    assert_no_selector "#journal-tab .rating-tab-notes"
    rating_tab.send_keys(:arrow_right)
    journal_tab = find('[role="tab"][aria-selected="true"]', text: I18n.t("ratings.browser.panels.journal"))
    assert_equal journal_tab, page.evaluate_script("document.activeElement")
    notes = find_field(I18n.t("ratings.browser.notes"))
    notes.set("Draft notes")
    assert_selector "#journal-tab .rating-tab-notes"
    notes.set(" ")
    assert_no_selector "#journal-tab .rating-tab-notes"
    notes.set("")
    notes.send_keys("First line", :enter, "Second line")
    assert_equal "First line\nSecond line", notes.value
    assert_button I18n.t("ratings.browser.save"), disabled: true
    journal_tab.send_keys(:arrow_left)
    assert_no_field I18n.t("ratings.browser.notes")
    assert_selector "#journal-tab .rating-tab-notes"
    assert_equal I18n.t("ratings.browser.panels.has_notes"), journal_tab["aria-description"]
    choice = find(".rating-choice", text: I18n.t("ratings.values.brilliant"))
    idle_background = choice.style("background-color")
    choice.hover
    assert_not_equal idle_background, choice.style("background-color")
    choose I18n.t("ratings.values.brilliant"), allow_label_click: true
    save.hover
    assert_equal "hidden", page.evaluate_script("getComputedStyle(arguments[0], '::after').visibility", save)
    journal_tab.click
    assert_equal "First line\nSecond line", find_field(I18n.t("ratings.browser.notes")).value
    rating_tab.click
    click_button I18n.t("ratings.browser.save")
    assert_selector '[role="status"]', text: I18n.t("ratings.browser.saved_with_notes")
    assert_equal Ratings::Rating::Values::BRILLIANT, Ratings::Rating.sole.value
    assert_equal "First line\nSecond line", Ratings::Rating.sole.notes
  end

  test "the rating and journal panels share a height and their tabs fit at narrow widths" do
    overview = ("The road led to a house that should not have been there. " * 12).strip
    film = Registry::Film.create!(title: "The last house at the end of the old road", tmdb_id: 1620, tmdb_metadata: { details: { overview: } })
    visit new_rating_path
    click_button I18n.t("identity.entry.try_it_out")
    click_button I18n.t("ratings.onboarding.surprise")
    assert_selector ".rating-film-header h2", text: film.title
    rating_tab = find('[role="tab"]', exact_text: I18n.t("ratings.browser.panels.rating"))
    journal_tab = find('[role="tab"]', exact_text: I18n.t("ratings.browser.panels.journal"))
    journal_tab.click
    fill_in I18n.t("ratings.browser.notes"), with: "The atmosphere stayed with me."
    assert_selector "#journal-tab .rating-tab-notes"

    [ 1080, 900, 651, 390, 320 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width:, height: 1000, deviceScaleFactor: 1, mobile: false)
      rating_tab.click
      rating = find("#rating-panel").rect
      actions = find(".rating-actions").rect
      strip = find('[role="tablist"]').rect
      assert_tab_labels_fit

      if width <= 650
        first_tab, last_tab = [ rating_tab, journal_tab ].map(&:rect)
        assert_equal first_tab.y, last_tab.y
        assert_in_delta first_tab.width, last_tab.width, 1
        assert_in_delta rating.x, first_tab.x, 1
        assert_in_delta rating.x + rating.width, last_tab.x + last_tab.width, 1
        poster = find(".rating-film-artwork .film-poster").rect
        title = find(".rating-film-heading h2").rect
        links = find(".rating-film-links").rect
        synopsis = find(".rating-mobile-synopsis .film-synopsis-text")
        lines = synopsis_lines(synopsis, limit: nil)
        first_x, first_y, = lines.first
        last_x, last_y, = lines.last
        assert_operator poster.x + poster.width, :<, title.x
        assert_in_delta poster.y, title.y, 1
        assert_operator first_y, :>=, links.y + links.height
        assert_operator first_y, :<, poster.y + poster.height
        assert_operator first_x, :>, poster.x + poster.width
        assert_operator last_y, :>, poster.y + poster.height
        assert_in_delta poster.x, last_x, 1
        assert_operator poster.y + poster.height, :<=, strip.y
        assert_operator synopsis.rect.y + synopsis.rect.height, :<, strip.y
        assert_operator strip.y + strip.height, :<=, rating.y
        choices = find(".rating-choices").rect
        assert_in_delta rating.y, choices.y, 1
        assert_in_delta rating.y + rating.height, choices.y + choices.height, 1
        assert_no_selector "#rating-panel .film-synopsis"
      end

      journal_tab.click
      journal = find("#journal-panel").rect
      notes = find_field(I18n.t("ratings.browser.notes"))
      assert_equal "none", notes.style("resize").fetch("resize")
      assert_in_delta journal.y + journal.height, notes.rect.y + notes.rect.height, 1
      assert_equal rating, journal, "Panel dimensions at #{width}px"
      assert_equal actions, find(".rating-actions").rect, "Footer position at #{width}px"
      assert_equal strip, find('[role="tablist"]').rect, "Tab strip dimensions at #{width}px"
      assert_no_selector "#rating-panel"
      assert_selector ".rating-mobile-synopsis .film-synopsis-text", text: overview if width <= 650
      assert_tab_labels_fit
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  private

  def assert_tab_labels_fit
    assert page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('.rating-tabs [role="tab"]')).every(tab => {
        const range = document.createRange()
        range.selectNodeContents(tab.firstChild)
        const lines = range.getClientRects()
        const bounds = tab.getBoundingClientRect()
        if (lines.length !== 1 || lines[0].left < bounds.left || lines[0].right > bounds.right) return false

        const icon = tab.querySelector(".rating-tab-notes:not([hidden]) svg")?.getBoundingClientRect()
        return !icon || (icon.left >= lines[0].right && icon.right <= bounds.right)
      })
    JS
  end

  def synopsis_lines(synopsis, limit: 2)
    lines = page.evaluate_script(<<~JS, synopsis)
      ((synopsis) => {
        const range = document.createRange()
        range.selectNodeContents(synopsis)
        return Array.from(range.getClientRects(), ({ x, y, width }) => [x + window.scrollX, y + window.scrollY, width])
      })(arguments[0])
    JS
    limit ? lines.first(limit) : lines
  end
end
