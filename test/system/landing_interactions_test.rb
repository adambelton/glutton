require "application_system_test_case"
require "support/marketing_catalogue"

class LandingInteractionsTest < ApplicationSystemTestCase
  include MarketingCatalogue
  test "theme selection survives navigation and reload" do
    visit root_path
    assert_selector "html:not([data-theme])"
    assert_equal "dark", find("html").style("color-scheme").fetch("color-scheme")
    assert_selector 'button.theme-toggle[aria-pressed="true"]'
    click_button I18n.t("ui.dark_mode")
    assert_selector 'html[data-theme="light"]'
    assert_equal "light", find("html").style("color-scheme").fetch("color-scheme")
    visit new_session_path
    assert_selector 'html[data-theme="light"]'
    refresh
    assert_selector 'button.theme-toggle[aria-pressed="false"]'
    click_button I18n.t("ui.dark_mode")
    assert_selector "html:not([data-theme])"
    assert_equal "dark", find("html").style("color-scheme").fetch("color-scheme")
  end

  def preview(feature)
    find("section.marketing-feature[aria-labelledby='#{feature}-preview-heading']")
  end

  test "ratings heading and preview appear in the initial desktop and mobile viewport" do
    create_preview_catalogue
    [ [ 1366, 768 ], [ 390, 844 ] ].each do |width, height|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width:, height:, deviceScaleFactor: 1, mobile: false)
      visit root_path
      assert_selector "h1", text: I18n.t("identity.entry.title"), normalize_ws: true
      heading = find("#ratings-preview-heading")
      card = preview(:ratings).find(".demo-browser")
      bounds = page.evaluate_script("((heading, card) => ({ headingTop: heading.getBoundingClientRect().top, headingBottom: heading.getBoundingClientRect().bottom, cardTop: card.getBoundingClientRect().top, scroll: scrollY }))(arguments[0], arguments[1])", heading, card)
      assert_equal 0, bounds.fetch("scroll")
      assert_operator bounds.fetch("headingTop"), :>=, 0
      assert_operator bounds.fetch("headingBottom"), :<=, height
      assert_operator bounds.fetch("cardTop") + 40, :<=, height, "Ratings card starts below the fold at #{width}px: #{bounds}"
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "sample selections stay still until the visitor chooses another" do
    create_preview_catalogue
    visit root_path
    within preview(:ratings) do
      click_button I18n.t("identity.entry.demo.select", position: 3, count: 3)
      assert_selector "h2", text: "The Substance"
    end
    within preview(:recommendations) do
      click_button I18n.t("identity.entry.demo.select", position: 2, count: 3)
      assert_selector "h2", text: "The Witch"
    end
    assert_no_selector ".demo-rotation"
    find("h1").hover.click
    sleep 10.2
    within(preview(:ratings)) { assert_selector "h2", text: "The Substance" }
    within(preview(:recommendations)) { assert_selector "h2", text: "The Witch" }
  end

  test "manual selection remains independent with reduced motion" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    create_preview_catalogue
    visit root_path
    within preview(:recommendations) do
      click_button I18n.t("identity.entry.demo.select", position: 3, count: 3)
      assert_selector "h2", text: "Backrooms"
    end
    within preview(:ratings) do
      assert_selector "h2", text: "Alien"
      assert_includes find("textarea").value, "The industrial spaceship felt like a real workplace."
      click_button I18n.t("identity.entry.demo.select", position: 2, count: 3)
      assert_equal I18n.t("identity.entry.demo.examples.the_thing.notes"), find("textarea").value
    end
    within(preview(:recommendations)) { assert_selector "h2", text: "Backrooms" }
    within(preview(:profile)) { assert_no_selector ".demo-controls" }
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  test "the full profile stays visible without repeated notes or evidence" do
    visit root_path
    within preview(:profile) do
      assert_selector ".profile-narrative", count: 1
      assert_selector ".profile-quality-item", count: 20
      assert_text "Slow pacing appeals to you when each quiet scene changes what you expect"
      assert_text "The Thing (1982) is a favourite"
      assert_no_selector ".profile-evidence-list, .profile-annotation", visible: :all
      assert_selector ".profile-quality-item:not([open])", count: 20
      definition = I18n.t("identity.entry.profile_sample.qualities.slow_building_tension.definition")
      assert_no_text definition
      find("summary", text: "Slow-building tension").send_keys(:enter)
      assert_selector ".profile-quality-item[open]", count: 1
      assert_text definition
      find("summary", text: "Slow-building tension").send_keys(:enter)
      assert_no_selector ".profile-quality-item[open]"
      assert_no_text definition
    end
  end

  test "sample library tabs and filters use only local state while search stays disabled" do
    create_preview_catalogue
    visit root_path
    assert_no_difference [ "Identity::User.count", "Identity::Session.count", "Ratings::Rating.count", "Library::LibraryFilm.count", "Recommendations::RecommendationFilm.count" ] do
      within preview(:library) do
        assert_selector 'input[type="search"]:disabled'
        search = find('input[type="search"]')
        assert_equal "none", search.style("pointer-events").fetch("pointer-events")
        page.driver.browser.action.move_to(search.native).click.perform
        assert_not page.evaluate_script("document.activeElement === arguments[0]", search)
        assert_selector ".library-film", count: 3
        find("button", text: I18n.t("library.browser.views.watched"), exact_text: true).send_keys(:enter)
        assert_selector ".library-film", count: 20
        click_button I18n.t("ratings.values.brilliant")
        assert_selector ".library-film", count: 5
        assert_selector ".library-film h3", text: "The Thing (1982)"
        assert_no_selector ".library-film h3", text: "The Thing (2011)"
        assert_selector 'button[value="brilliant"][aria-pressed="true"]'
        click_button I18n.t("ratings.values.pretty_good")
        assert_selector ".library-film", count: 11
        click_button I18n.t("ratings.values.brilliant")
        assert_selector ".library-film", count: 6
        assert_selector ".library-film h3", text: "The Substance"
        assert_selector ".library-film h3", text: "Jacob's Ladder"
        click_button I18n.t("ratings.values.pretty_good")
        click_button I18n.t("ratings.values.not_for_me")
        assert_selector ".library-film", count: 4
        assert_selector ".library-film h3", text: "The Blair Witch Project"
        assert_selector ".library-film h3", text: "The Thing (2011)"
        click_button I18n.t("ratings.values.garbage")
        assert_selector ".library-film", count: 7
        click_button I18n.t("library.browser.clear_rating_filters")
        assert_selector ".library-film", count: 20
        click_button I18n.t("library.browser.unrated")
        assert_selector ".library-film", count: 2
        assert_selector ".library-film h3", text: "Sinners"
        assert_selector ".library-film h3", text: "Suspiria"
        click_button I18n.t("library.browser.views.watchlist")
        assert_selector ".library-film", count: 3
        click_button I18n.t("library.browser.views.watched")
        assert_selector ".library-film", count: 2
        assert_text I18n.t("identity.entry.library_count", count: 2)
        click_button I18n.t("library.browser.clear_rating_filters")
        assert_selector ".library-film", count: 20
        assert_selector '.library-preview-search:disabled form[method="get"]', count: 1
        assert_no_selector "form input:enabled, form button:enabled"
        assert_selector ".library-card-actions button:disabled", visible: :all
      end
    end
    assert_equal root_path, page.current_path
  end

  test "sample filters show an empty state when catalogue examples are unavailable" do
    create_preview_catalogue(except: [ 60935, 23437, 439079, 2667 ])
    visit root_path
    within preview(:library) do
      click_button I18n.t("library.browser.views.watched")
      assert_selector ".library-film", count: 16
      click_button I18n.t("ratings.values.not_for_me")
      assert_no_selector ".library-film"
      assert_text I18n.t("identity.entry.library_empty")
      assert_text I18n.t("identity.entry.library_count", count: 0)
      click_button I18n.t("library.browser.clear_rating_filters")
      assert_selector ".library-film", count: 16
    end
  end

  test "complete previews stay static and fit desktop tablet and narrow screens" do
    create_preview_catalogue
    visit root_path
    assert_selector ".marketing-feature", count: 4
    within preview(:ratings) do
      choice = find(".demo-frame:not([hidden]) .rating-choice label", match: :first)
      choice.hover
      assert_equal "default", choice.style("cursor").fetch("cursor")
      assert_equal "default", find(".demo-frame:not([hidden]) textarea").style("cursor").fetch("cursor")
    end
    within preview(:recommendations) do
      assert_selector ".recommendation-trailer-still", count: 1
      assert_selector ".recommendation-film button:disabled", count: 3
      assert_equal "default", find(".recommendation-film button", match: :first).style("cursor").fetch("cursor")
    end
    within preview(:library) do
      click_button I18n.t("library.browser.views.watched")
      assert_selector 'input[type="search"]:disabled'
      assert_selector ".library-card-actions button:disabled"
    end
    assert_no_selector ".marketing-preview a[href], .marketing-preview iframe"
    assert_selector '.library-preview-search:disabled form[method="get"]', count: 1
    assert_no_selector ".marketing-preview form input:enabled, .marketing-preview form button:enabled"
    assert_no_selector ".demo-frame button:enabled, .account-page button:enabled"

    [ [ 1400, 1000 ], [ 800, 1000 ], [ 390, 844 ] ].each do |width, height|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width:, height:, deviceScaleFactor: 1, mobile: false)
      assert_equal width, page.evaluate_script("window.innerWidth")
      assert_selector ".marketing-feature", count: 4
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "Overflow at #{width}px"
      all(".marketing-preview .demo-browser", count: 4).each do |card|
        style = card.style("padding-top", "padding-right", "padding-bottom", "padding-left", "border-top-width", "background-color")
        if width <= 650
          %w[padding-top padding-right padding-bottom padding-left border-top-width].each { |property| assert_equal "0px", style.fetch(property) }
          assert_equal "rgba(0, 0, 0, 0)", style.fetch("background-color")
        else
          assert_equal "28px", style.fetch("padding-left")
          assert_equal "1px", style.fetch("border-top-width")
        end
      end
      %i[ratings recommendations].each do |feature|
        within preview(feature) do
          card = find(".demo-browser")
          controls = find(".demo-controls")
          gap = page.evaluate_script("arguments[1].getBoundingClientRect().top - arguments[0].getBoundingClientRect().bottom", card, controls)
          assert_operator gap, :>=, 0, "Controls overlap the #{feature} card at #{width}px"
        end
      end
      within preview(:recommendations) do
        thumbnail = find(".demo-frame:not([hidden]) .recommendation-trailer-thumbnail")
        play_symbol = find(".demo-frame:not([hidden]) .recommendation-trailer-play")
        offset = page.evaluate_script("((image, symbol) => { const i = image.getBoundingClientRect(); const s = symbol.getBoundingClientRect(); return [Math.abs(i.left + i.width / 2 - s.left - s.width / 2), Math.abs(i.top + i.height / 2 - s.top - s.height / 2)]; })(arguments[0], arguments[1])", thumbnail, play_symbol)
        offset.each { |distance| assert_operator distance, :<=, 1 }
        assert_equal "none", play_symbol.style("pointer-events").fetch("pointer-events")
      end
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
