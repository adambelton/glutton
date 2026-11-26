require "application_system_test_case"
require "support/marketing_catalogue"

class LandingInteractionsTest < ApplicationSystemTestCase
  include MarketingCatalogue
  test "theme selection survives navigation and reload" do
    visit root_path
    assert_selector "html:not([data-theme])"
    assert_equal "dark", find("html").style("color-scheme").fetch("color-scheme")
    assert_equal "rgba(195, 38, 48, 1)", find(".hero-horror").style("color").fetch("color")
    assert_selector 'button.theme-toggle[aria-pressed="true"]'
    click_button I18n.t("ui.dark_mode")
    assert_selector 'html[data-theme="light"]'
    assert_equal "light", find("html").style("color-scheme").fetch("color-scheme")
    assert_equal "rgba(143, 16, 27, 1)", find(".hero-horror").style("color").fetch("color")
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

  test "entry actions move from the header to full-width rows on mobile" do
    [ [ 1366, 768 ], [ 390, 844 ] ].each do |width, height|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width:, height:, deviceScaleFactor: 1, mobile: false)
      visit root_path
      assert_selector "h1", text: I18n.t("identity.entry.title"), normalize_ws: true
      mobile = width <= 650
      assert_no_selector(mobile ? ".ui-header .ui-auth-links" : ".hero-entry-actions")
      row = find(mobile ? ".hero-entry-actions" : ".ui-header .ui-auth-links")
      within row do
        assert_link I18n.t("ui.register"), href: new_registration_path
        assert_link I18n.t("ui.log_in"), href: new_session_path
        button = find("button", text: I18n.t("identity.entry.try_it_out"))
        bounds = page.evaluate_script("arguments[0].getBoundingClientRect().toJSON()", button)
        assert_operator bounds.fetch("bottom"), :<=, height
        assert_operator bounds.fetch("left"), :>=, 0
        assert_operator bounds.fetch("right"), :<=, width
      end
      closing = find(".demo-entry")
      closing_actions = closing.find(".preview-actions")
      unless mobile
        assert_selector ".preview-actions a.ui-link", exact_text: I18n.t("ui.register")
        assert_no_selector ".preview-actions a.ui-action-button", exact_text: I18n.t("ui.register")
        next
      end

      hero = find(".demo-intro")
      guest = row.find_button(I18n.t("identity.entry.try_it_out"))
      login = row.find_link(I18n.t("ui.log_in"))
      assert_in_delta hero.rect.x, guest.rect.x, 1
      assert_in_delta hero.rect.width, guest.rect.width, 1
      assert_operator login.rect.y, :>, guest.rect.y + guest.rect.height
      assert_full_width_entry_actions(row, hero, selector: "a.ui-action-button", count: 2)
      description = hero.all("p").last.rect
      assert_operator row.rect.y - (description.y + description.height), :>, 28
      guest.send_keys(:tab)
      assert_equal login, page.evaluate_script("document.activeElement")

      assert_full_width_entry_actions(closing_actions, closing, count: 2)
      expected_gap = closing_actions.evaluate_script("parseFloat(getComputedStyle(this).getPropertyValue('--glutton-action-gap'))")
      assert_in_delta expected_gap, closing_actions.style("column-gap").fetch("column-gap").to_f, 0.1
      register = closing_actions.find_link(I18n.t("ui.register"), href: new_registration_path)
      assert_selector ".preview-actions a.ui-action-button", exact_text: I18n.t("ui.register")
      assert_equal "rgba(0, 0, 0, 0)", register.style("background-color").fetch("background-color")
    end
    within(".hero-entry-actions") { click_link I18n.t("ui.register") }
    assert_current_path new_registration_path
    visit root_path
    within(".hero-entry-actions") { click_link I18n.t("ui.log_in") }
    assert_current_path new_session_path
    visit root_path
    within(".hero-entry-actions") { click_button I18n.t("identity.entry.try_it_out") }
    assert_current_path new_rating_path
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  def assert_full_width_entry_actions(group, container, count:, selector: ".ui-action-button")
    actions = group.all(selector, count:).map(&:rect)
    assert_equal 1, actions.map(&:y).uniq.size
    actions.drop(1).each { |action| assert_in_delta actions.first.width, action.width, 1 }
    assert_in_delta container.rect.x, actions.first.x, 1
    assert_in_delta container.rect.x + container.rect.width, actions.last.x + actions.last.width, 1
  end

  test "FAQ questions disclose answers with Enter and Space using native accessible semantics" do
    visit root_path
    within ".marketing-faq" do
      assert_selector "details:not([open])", count: 7
      question = find("summary", text: "Who makes Glutton?")
      assert_no_text "I'm Adam."
      question.send_keys(:enter)
      assert_selector "details[open]", count: 1
      assert_text "I'm Adam."
      assert_equal question, page.evaluate_script("document.activeElement")
      question.send_keys(:space)
      assert_no_selector "details[open]"
      assert_no_text "I'm Adam."
      question.send_keys(:tab)
      assert_equal find("summary", text: "Is Glutton free?"), page.evaluate_script("document.activeElement")
      find("summary", text: "Is Glutton free?").send_keys(:space)
      assert_text "Glutton is completely free to use, with no ads."
    end
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
      assert_selector ".recommendation-match-value", exact_text: I18n.t("recommendations.match.percentage", percentage: 91)
      find(".recommendation-match").hover
      assert_no_selector '[role="tooltip"], .recommendation-match[tabindex]', visible: :all
      click_button I18n.t("identity.entry.demo.select", position: 3, count: 3)
      assert_selector "h2", text: "Backrooms"
      assert_selector ".recommendation-match-value", exact_text: I18n.t("recommendations.match.percentage", percentage: 82)
    end
    within preview(:ratings) do
      assert_selector "h2", text: "Alien"
      assert_selector '[role="tab"] .rating-tab-notes svg', count: 1
      find('[role="tab"]', text: I18n.t("ratings.browser.panels.journal")).click
      assert_includes find("textarea").value, "The industrial spaceship felt like a real workplace."
      click_button I18n.t("identity.entry.demo.select", position: 2, count: 3)
      assert_selector '[role="tab"] .rating-tab-notes svg', count: 1
      find('[role="tab"]', text: I18n.t("ratings.browser.panels.journal")).click
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
        assert_equal I18n.t("library.browser.search.watchlist"), search["placeholder"]
        assert_equal "none", search.style("pointer-events").fetch("pointer-events")
        page.driver.browser.action.move_to(search.native).click.perform
        assert_not page.evaluate_script("document.activeElement === arguments[0]", search)
        assert_selector ".library-film", count: 2
        find("button", text: I18n.t("library.browser.views.watched"), exact_text: true).send_keys(:enter)
        assert_selector ".library-film", count: 8
        assert_selector 'input[type="search"]:disabled[placeholder="Search your watched films"]'
        assert_selector ".library-card-actions button:disabled", count: 16
        click_button I18n.t("ratings.values.brilliant")
        assert_selector ".library-film", count: 2
        assert_selector ".library-film h3", text: "The Thing (1982)"
        assert_no_selector ".library-film h3", text: "The Thing (2011)"
        assert_selector 'button[value="brilliant"][aria-pressed="true"]'
        click_button I18n.t("ratings.values.pretty_good")
        assert_selector ".library-film", count: 4
        click_button I18n.t("ratings.values.brilliant")
        assert_selector ".library-film", count: 2
        assert_selector ".library-film h3", text: "The Substance"
        assert_selector ".library-film h3", text: "Jacob's Ladder"
        click_button I18n.t("ratings.values.pretty_good")
        click_button I18n.t("ratings.values.not_for_me")
        assert_selector ".library-film", count: 2
        assert_selector ".library-film h3", text: "The Blair Witch Project"
        assert_selector ".library-film h3", text: "The Thing (2011)"
        click_button I18n.t("ratings.values.garbage")
        assert_selector ".library-film", count: 3
        click_button I18n.t("library.browser.clear_rating_filters")
        assert_selector ".library-film", count: 8
        click_button I18n.t("library.browser.unrated")
        assert_selector ".library-film", count: 1
        assert_selector ".library-film h3", text: "Sinners"
        click_button I18n.t("library.browser.views.watchlist")
        assert_selector ".library-film", count: 2
        click_button I18n.t("library.browser.views.watched")
        assert_selector ".library-film", count: 1
        click_button I18n.t("library.browser.clear_rating_filters")
        assert_selector ".library-film", count: 8
        assert_selector '.library-preview-search:disabled input[type="search"]', count: 1
        assert_no_selector "form input:enabled, form button:enabled"
        assert_selector ".library-card-actions button:disabled", visible: :all
      end
    end
    assert_equal root_path, page.current_path
  end

  test "sample filters show an empty state when catalogue examples are unavailable" do
    create_preview_catalogue(except: [ 60935, 2667 ])
    visit root_path
    within preview(:library) do
      click_button I18n.t("library.browser.views.watched")
      assert_selector ".library-film", count: 6
      click_button I18n.t("ratings.values.not_for_me")
      assert_no_selector ".library-film"
      assert_text I18n.t("identity.entry.library_empty")
      click_button I18n.t("library.browser.clear_rating_filters")
      assert_selector ".library-film", count: 6
    end
  end

  test "ratings and recommendation previews disclose long synopses" do
    overview = ("A visitor arrives in a town where nobody goes out after dark. " * 18).strip
    create_preview_catalogue(overviews: { 348 => overview, 310131 => overview })
    visit root_path

    %i[ratings recommendations].each do |feature|
      within preview(feature) do
        if feature == :recommendations
          click_button I18n.t("identity.entry.demo.select", position: 2, count: 3)
          assert_selector "h2", text: "The Witch"
        end
        expand = find_button I18n.t("ui.synopsis.expand")
        toggle = expand.rect
        assert_equal [ 32, 24 ], [ toggle.width, toggle.height ]
        synopsis = find(".film-synopsis-text")
        collapsed = synopsis.rect
        assert_in_delta 2 * synopsis.style("line-height").fetch("line-height").to_f, collapsed.height, 1
        expand.click
        assert_button I18n.t("ui.synopsis.collapse")
        assert_operator synopsis.rect.height, :>, collapsed.height
        synopsis.send_keys(:escape)
        assert_button I18n.t("ui.synopsis.expand")
        assert_equal collapsed, synopsis.rect
      end
    end

    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    %i[ratings recommendations].each do |feature|
      within preview(feature) do
        synopsis = find(".film-synopsis-text")
        assert_no_button I18n.t("ui.synopsis.expand")
        assert_equal "none", synopsis.style("-webkit-line-clamp").fetch("-webkit-line-clamp")
        assert page.evaluate_script("arguments[0].clientHeight === arguments[0].scrollHeight", synopsis)
      end
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "complete previews stay static and fit desktop tablet and narrow screens" do
    create_preview_catalogue
    visit root_path
    assert_selector ".marketing-feature", count: 4
    primary_properties = %w[background-color color opacity]
    primary_style = find_button(I18n.t("identity.entry.try_it_out")).style(*primary_properties)
    within preview(:ratings) do
      choice = find(".demo-frame:not([hidden]) .rating-choice label", match: :first)
      choice.hover
      assert_equal "default", choice.style("cursor").fetch("cursor")
      within ".demo-frame:not([hidden]) .rating-actions" do
        save = find_button(I18n.t("ratings.browser.save"), disabled: true)
        assert_equal primary_style, save.style(*primary_properties)
        assert_button I18n.t("ratings.browser.dismiss"), disabled: true
        assert_button I18n.t("library.detail.add_to_watchlist"), disabled: true
        assert all("button:disabled", count: 3).all? { |button| button.style("opacity").fetch("opacity") == "1" }
      end
      find('[role="tab"]', text: I18n.t("ratings.browser.panels.journal")).click
      assert_equal "default", find(".demo-frame:not([hidden]) textarea").style("cursor").fetch("cursor")
    end
    within preview(:recommendations) do
      assert_selector ".recommendation-trailer-still", count: 1
      assert_no_text "Trailer preview"
      assert_selector ".recommendation-film button:disabled", count: 3
      accept = find_button(I18n.t("recommendations.accept"), disabled: true)
      assert_equal primary_style, accept.style(*primary_properties)
      assert all(".recommendation-film button:disabled", count: 3).all? { |button| button.style("opacity").fetch("opacity") == "1" }
      assert_equal "default", find(".recommendation-film button", match: :first).style("cursor").fetch("cursor")
    end
    within preview(:library) do
      click_button I18n.t("library.browser.views.watched")
      assert_selector 'input[type="search"]:disabled'
      assert_selector ".library-card-actions button:disabled"
    end
    assert_no_selector ".marketing-preview a[href], .marketing-preview iframe"
    assert_selector '.library-preview-search:disabled input[type="search"]', count: 1
    assert_no_selector ".marketing-preview form input:enabled, .marketing-preview form button:enabled"
    assert_no_selector ".demo-frame button:enabled:not([role=tab], .film-synopsis-toggle), .account-page button:enabled"

    [ [ 1400, 1000 ], [ 800, 1000 ], [ 390, 844 ] ].each do |width, height|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width:, height:, deviceScaleFactor: 1, mobile: false)
      assert_equal width, page.evaluate_script("window.innerWidth")
      assert_selector ".marketing-feature", count: 4
      assert_equal preview(:recommendations).style("margin-top"), preview(:ratings).style("margin-top")
      all(".marketing-faq details:not([open]) > summary").each { |question| question.click }
      assert_selector ".marketing-faq details[open]", count: 7
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "Overflow at #{width}px"
      if width <= 650
        within preview(:library) do
          all(".library-tabs button", count: 2).each do |tab|
            assert_equal "center", tab.style("justify-content").fetch("justify-content")
          end
        end
      end
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
