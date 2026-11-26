require "application_system_test_case"

class LibraryCollectionNavigationTest < ApplicationSystemTestCase
  test "touch confirmation keeps the paginated TMDB results open when canceled or applied" do
    client = Registry::Sources::TmdbClient
    original_search = client.method(:search)
    client.define_singleton_method(:search) do |query:, page:, **|
      results = 7.times.map do |index|
        { "id" => 600 + index, "title" => "#{query} #{index + 1}", "genre_ids" => [ 27 ] }
      end
      { "page" => page, "total_pages" => 1, "total_results" => results.size, "results" => results }
    end
    film = Registry::Film.create!(title: "Alien 6", tmdb_id: 605)

    visit library_path
    click_button I18n.t("identity.entry.try_it_out")
    assert_current_path library_path
    visit library_path(view: "watched")
    click_button I18n.t("ui.search.tmdb")
    fill_in I18n.t("library.search.label"), with: "Alien"

    within ".library-film-search-dropdown" do
      click_link I18n.t("library.browser.next")
      assert_text I18n.t("library.browser.page", number: 2)
    end
    user = Identity::UserGuest.last
    browser = page.driver.browser
    browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: true, maxTouchPoints: 1)
    result = find(".library-film-search-dropdown li", text: "Alien 6")
    action = result.find_button(I18n.t("library.detail.add_to_watched"))
    tap_library_action(action)
    assert_selector "#library-action-confirmation[open]"
    assert_no_selector ".film-search-tooltip"
    within "#library-action-confirmation[open]" do
      assert_selector "h2", text: I18n.t("library.detail.add_to_watched")
      assert_selector "p", text: "Alien 6"
      assert_selector "button:focus", text: I18n.t("library.confirmation.cancel")
      click_button I18n.t("library.confirmation.cancel")
    end
    assert_no_selector "#library-action-confirmation[open]"
    assert_selector ".library-film-search-dropdown li", text: "Alien 6"
    assert_not Library::LibraryFilm.watched.exists?(user:, film:)

    tap_library_action(action)
    within "#library-action-confirmation[open]" do
      click_button I18n.t("library.confirmation.confirm")
    end

    assert_selector ".ui-toast", text: I18n.t("library.detail.watched")
    assert_field I18n.t("library.search.label"), with: "Alien"
    within ".library-film-search-dropdown" do
      assert_text I18n.t("library.browser.page", number: 2)
      assert_selector "li", text: /Alien 6.*#{I18n.t("library.search.in_watched")}/m
      assert_selector "li", text: "Alien 7"
    end
    assert_selector '.library-film h3 a[href="https://www.themoviedb.org/movie/605"][target="_blank"]', text: "Alien 6"
    assert_current_path library_path(view: "watched")
    assert Library::LibraryFilm.watched.exists?(user:, film:)
    click_button I18n.t("ui.search.clear")
    assert_field I18n.t("library.search.label"), with: ""
    assert_no_selector ".library-film-search-dropdown"
  ensure
    browser&.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false)
    client.define_singleton_method(:search, original_search)
  end

  test "touching remove on a Library card only removes the film after confirmation" do
    visit library_path
    click_button I18n.t("identity.entry.try_it_out")
    assert_current_path library_path
    user = Identity::UserGuest.last
    film = Registry::Film.create!(title: "The Thing")
    Library::CollectionManagement::AddToWatchlist.call(user_id: user.id, film_id: film.id)

    browser = page.driver.browser
    browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 900, deviceScaleFactor: 1, mobile: true)
    browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: true, maxTouchPoints: 1)
    visit library_path
    remove = find_button(I18n.t("library.detail.remove_film", title: film.title))
    assert_equal "none", page.evaluate_script("getComputedStyle(arguments[0], '::after').content", remove)
    tap_library_action(remove)

    within "#library-action-confirmation[open]" do
      assert_selector "h2", text: I18n.t("library.detail.remove_from_watchlist")
      assert_selector "p", text: film.title
      assert Library::LibraryFilm.exists?(user:, film:)
      cancel = find_button(I18n.t("library.confirmation.cancel"))
      confirm = find_button(I18n.t("library.confirmation.confirm"))
      actions = find(".ui-actions").rect
      assert_in_delta actions.x, cancel.rect.x, 1
      assert_in_delta actions.x + actions.width, confirm.rect.x + confirm.rect.width, 1
      assert_in_delta cancel.rect.y, confirm.rect.y, 1
      assert_in_delta cancel.rect.width, confirm.rect.width, 1
      tap_library_action(confirm)
    end
    assert_no_selector ".library-film h3", text: film.title
    assert_selector ".ui-toast", text: I18n.t("library.detail.removed")
    assert_not Library::LibraryFilm.exists?(user:, film:)
  ensure
    browser&.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false)
    browser&.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "film search from the Library heading adds a result to Watchlist" do
    client = Registry::Sources::TmdbClient
    original_search = client.method(:search)
    client.define_singleton_method(:search) do |query:, page:, **|
      sleep 0.4
      results = (page == 1 ? 7 : 5).times.map do |index|
        { "id" => 348 + 20 * (page - 1) + index, "title" => (page == 1 && index.zero? ? query : "#{query} #{page}-#{index + 1}"),
          "release_date" => "1979-05-25", "poster_path" => ("/alien.jpg" unless index == 6), "genre_ids" => [ 27 ],
          "overview" => "A crew answers a distress signal on a distant moon." }
      end
      { "page" => page, "total_pages" => 2, "total_results" => 12, "results" => results }
    end
    Registry::Film.create!(title: "Alien", tmdb_id: 348)

    visit library_path
    click_button I18n.t("identity.entry.try_it_out")
    click_button I18n.t("ui.search.tmdb")
    heading = find(".ui-page-heading h1").rect
    search_field = find("#library-film-query").rect
    modes = find(".search-bar-modes").rect
    assert_in_delta 480, search_field.width, 1
    assert_operator modes.x + modes.width, :<, search_field.x
    assert_equal [ 72, 72 ], all(".search-bar-modes button").map { |button| button.rect.width }
    assert_in_delta heading.height, search_field.height, 1
    assert_in_delta heading.y, search_field.y, 1
    within ".ui-page-heading" do
      fill_in I18n.t("library.search.label"), with: "Alien"
      assert_no_selector "form[role=search] button[type=submit]"
    end

    assert_selector ".collection-search-spinner"
    spinner = find(".collection-search-spinner").rect
    field = find("#library-film-query").rect
    assert_operator spinner.x + spinner.width, :<=, field.x
    assert_selector ".library-film-search-dropdown h2", text: "Search results"
    assert_selector '.library-film-search-dropdown h3 a[href="https://www.themoviedb.org/movie/348"][target="_blank"][rel~="noopener"]',
      text: "Alien (1979)"
    assert_no_selector ".collection-search-spinner"
    assert_selector ".library-film-search-dropdown img[src$='/alien.jpg']"
    assert_selector ".library-film-search-dropdown .film-search-overview", count: 5,
      text: "A crew answers a distress signal"
    assert_selector ".library-film-search-dropdown button[aria-label='Mark watched'] svg"
    actions = first(".film-search-actions").rect
    details = first(".film-search-result-details").rect
    assert_operator actions.x, :>=, details.x + details.width
    assert_selector "#library-film-query:focus"
    assert_current_path library_path
    within ".library-film-search-dropdown" do
      assert_selector "li", count: 5
      assert_text "Page 1"
      assert_selector "h3 .film-year", text: "(1979)", count: 5
      last_result = all("li", count: 5).last.rect
      pagination = find(".film-search-pagination").rect
      assert_operator last_result.y + last_result.height, :<=, pagination.y
      watchlist_button = first("li").find_button(I18n.t("library.detail.add_to_watchlist"))
      watchlist_button.hover
      tooltip = find(".film-search-tooltip", text: I18n.t("library.detail.add_to_watchlist"))
      assert_operator tooltip.rect.y, :<, find(".film-search-content").rect.y
      assert tooltip.evaluate_script(<<~JS)
        (() => {
          const box = this.getBoundingClientRect()
          this.style.pointerEvents = "auto"
          const visible = document.elementFromPoint(box.x + box.width / 2, box.y + 2) === this
          this.style.pointerEvents = ""
          return visible
        })()
      JS
      find(".film-search-results-heading").hover
      assert_no_selector ".film-search-tooltip"
      watchlist_button.execute_script("this.focus()")
      assert_selector ".film-search-tooltip", text: I18n.t("library.detail.add_to_watchlist")
      click_link I18n.t("library.browser.next")
      assert_selector "li", count: 5
      assert_text "Alien 1-7"
      assert_text "Alien 2-3"
      poster = first("img.film-poster").rect
      within find("li", text: "Alien 1-7") do
        placeholder = find(".film-poster.poster-wordmark", text: I18n.t("ui.short_wordmark")).rect
        assert_equal [ poster.width, poster.height ], [ placeholder.width, placeholder.height ]
        assert_selector ".film-search-overview", text: "A crew answers a distress signal"
      end
      click_link I18n.t("library.browser.next")
      assert_selector "li", count: 2
      assert_text "Alien 2-5"
      assert_no_link I18n.t("library.browser.next")
      assert_current_path library_path
      click_link I18n.t("library.browser.previous")
      assert_text "Alien 1-7"
      click_link I18n.t("library.browser.previous")
      assert_selector "h3", text: "Alien (1979)", exact_text: true
      first("li").click_button I18n.t("library.detail.add_to_watchlist")
    end
    assert_selector ".ui-toast", text: I18n.t("library.detail.watchlisted")
    assert_field I18n.t("library.search.label"), with: "Alien"
    within ".library-film-search-dropdown" do
      assert_selector "li", text: /Alien \(1979\).*#{I18n.t("library.search.in_watchlist")}/m
      assert_selector "li", count: 5
    end
    assert_selector ".library-film h3", text: "Alien"
    assert_current_path library_path
  ensure
    client.define_singleton_method(:search, original_search)
  end

  test "local search filters the Library and the in-field clear restores the collection" do
    visit library_path
    click_button I18n.t("identity.entry.try_it_out")
    label = I18n.t("library.browser.search.watchlist")
    assert_field label, placeholder: label
    user = Identity::UserGuest.last
    [ "Alien", "The Thing" ].each do |title|
      film = Registry::Film.create!(title:)
      Library::CollectionManagement::AddToWatchlist.call(user_id: user.id, film_id: film.id)
    end
    visit library_path
    assert_button I18n.t("library.browser.title"), exact: true
    assert_no_field I18n.t("library.search.label")
    fill_in label, with: "alien"
    assert_selector ".library-film h3", text: "Alien"
    assert_no_selector ".library-film h3", text: "The Thing"
    assert_current_path %r{\A/library\?(?:view=watchlist&q=alien|q=alien&view=watchlist)\z}

    click_button I18n.t("ui.search.tmdb")
    assert_no_field label
    assert_field I18n.t("library.search.label")
    assert_no_selector ".library-film h3", text: "The Thing"
    click_button I18n.t("library.browser.title")
    assert_field label, with: "alien"
    assert_selector "#library-collection-query:focus"
    within ".collection-search-field" do
      click_link I18n.t("ui.search.clear")
    end
    assert_current_path library_path(view: "watchlist")
    assert_field label, with: ""
    assert_selector ".library-film h3", text: "The Thing"

    browser = page.driver.browser
    browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 900, deviceScaleFactor: 1, mobile: false)
    assert_stacked_library_search("library-collection-query")
    watchlist_tabs = find(".library-tabs").rect
    click_button I18n.t("ui.search.tmdb")
    assert_selector "#library-film-query:focus"
    assert_stacked_library_search("library-film-query")
    click_link I18n.t("library.browser.views.watched")
    assert_current_path library_path(view: "watched")
    assert_selector ".library-tabs [aria-current='page']", text: I18n.t("library.browser.views.watched")
    watched_search = I18n.t("library.browser.search.watched")
    assert_field watched_search, placeholder: watched_search
    assert_stacked_library_search("library-collection-query")
    tabs = find(".library-tabs")
    assert_equal watchlist_tabs, tabs.rect
    assert_operator tabs.style("border-bottom-width").fetch("border-bottom-width").to_f, :>, 0
    assert_operator tabs.rect.y + tabs.rect.height, :<=, find(".library-rating-filters").rect.y
  ensure
    browser&.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "Watched filters share the Watchlist divider position when they fit beside the tabs" do
    visit library_path
    click_button I18n.t("identity.entry.try_it_out")

    active_tab = find(".library-tabs [aria-current='page']", text: I18n.t("library.browser.views.watchlist"))
    assert_equal "8px", active_tab.style("border-top-left-radius").fetch("border-top-left-radius")
    watchlist_divider = divider_position

    within ".library-tabs" do
      click_link I18n.t("library.browser.views.watched")
    end
    assert_selector ".library-rating-filters"

    assert_equal watchlist_divider, divider_position
    clear_icon = find(".library-clear-filters[disabled] svg")
    clear_icon.hover
    assert_equal "not-allowed", clear_icon.style("cursor").fetch("cursor")

    label = I18n.t("ratings.values.brilliant")
    assert_equal "dark", find("html").style("color-scheme").fetch("color-scheme")
    within ".library-rating-filters" do
      pill = find_link(label)
      pill.hover
      hover_background = pill.style("background-color")
      pill.click
      selected = find('a[data-selected="true"]', text: label)
      selected.hover
      assert_not_equal hover_background, selected.style("background-color")
      colors = selected.style("color", "background-color")
      assert_not_equal colors.fetch("background-color"), colors.fetch("color")
      click_button I18n.t("library.browser.clear_rating_filters")
      assert_no_selector "[data-selected]"
      assert_button I18n.t("library.browser.clear_rating_filters"), disabled: true
    end
  end

  test "Library posters fill a full grid row at desktop and narrow widths" do
    visit library_path
    click_button I18n.t("identity.entry.try_it_out")
    assert_selector "#library-collection-results .library-tabs"
    user = Identity::UserGuest.last
    12.times do |index|
      film = Registry::Film.create!(title: "Grid film #{index + 1}")
      Library::CollectionManagement::AddToWatchlist.call(user_id: user.id, film_id: film.id)
    end
    visit library_path
    grid = find(".library-films")
    window = current_window
    original_width, original_height = window.size

    [ 1240, 580 ].each do |width|
      window.resize_to(width, original_height)
      posters = grid.all(".film-poster", count: 12).map(&:rect)
      first_row = posters.take_while { |poster| poster.y == posters.first.y }
      assert_operator first_row.size, :>, 1
      assert_in_delta grid.rect.x, first_row.first.x, 1
      assert_in_delta grid.rect.x + grid.rect.width, first_row.last.x + first_row.last.width, 1
    end
  ensure
    window&.resize_to(original_width, original_height)
  end

  test "Library ratings return to Watched with save feedback" do
    visit library_path
    click_button I18n.t("identity.entry.try_it_out")
    assert_current_path library_path
    user = Identity::UserGuest.last
    film = Registry::Film.create!(title: "Card action film")
    Library::CollectionManagement::AddToWatchlist.call(user_id: user.id, film_id: film.id)

    visit library_path
    within ".library-film" do
      assert_poster_action_row
      assert_no_button "Rate #{film.title}"
      assert_button "Remove #{film.title} from watchlist"
      find_button("Mark #{film.title} watched").send_keys(:enter)
    end

    assert_current_path new_rating_path(film_id: film.id)
    assert_selector "h2", text: film.title
    click_link I18n.t("library.browser.return")
    assert_current_path library_path(view: "watched")
    browser = page.driver.browser
    within ".library-film" do
      assert_poster_action_row
      rating = find_button("Rate #{film.title}")
      remove = find_button(I18n.t("library.detail.remove_film_from_library", title: film.title))
      assert_no_button I18n.t("library.detail.move_film_to_watchlist", title: film.title)
      assert_equal remove.style("background-color"), rating.style("background-color")
      if page.evaluate_script("matchMedia('(hover: hover)').matches")
        page.evaluate_script("arguments[0].style.transition = arguments[1].style.transition = 'none'", remove, rating)
        remove.hover
        assert_selector "button:hover"
        hover_background = remove.style("background-color")
        rating.hover
        assert_selector "button.library-rating-icon:hover"
        assert_equal hover_background, rating.style("background-color")
      end
      browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: true, maxTouchPoints: 1)
      tap_library_action(rating)
    end
    within "#library-action-confirmation[open]" do
      assert_selector "h2", text: "Add rating"
      assert_selector "p", text: film.title
      click_button I18n.t("library.confirmation.confirm")
    end
    assert_current_path new_rating_path(film_id: film.id)
    assert_selector "h2", text: film.title
    assert_link I18n.t("library.browser.return"), href: library_path(view: "watched")
    save = I18n.t("ratings.browser.save")
    journal = I18n.t("ratings.browser.panels.journal")
    toast = I18n.t("ratings.browser.saved_with_notes")
    save_button = find_button(save, disabled: true).rect
    rating_card = find(".rating-interface").rect
    assert_in_delta rating_card.x + rating_card.width, save_button.x + save_button.width, 1
    find('label[for="rating-brilliant"]').click
    find('[role="tab"]', text: journal).click
    fill_in "notes", with: "Original notes"
    click_button save
    assert_current_path library_path(view: "watched")
    assert_selector ".ui-toast", text: toast

    tap_library_action(find_button(I18n.t("library.browser.edit_film_rating", title: film.title)))
    within "#library-action-confirmation[open]" do
      assert_selector "h2", text: "Edit rating"
      assert_selector "p", text: film.title
      click_button I18n.t("library.confirmation.confirm")
    end
    assert_current_path edit_rating_path(film_id: film.id)
    browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false)
    assert_selector "#journal-tab .rating-tab-notes"
    assert_link I18n.t("library.browser.return"), href: library_path(view: "watched")
    assert_button save, disabled: true

    find('label[for="rating-pretty_good"]').click
    assert_button save, disabled: false
    find('label[for="rating-brilliant"]').click
    assert_button save, disabled: true

    oversized_notes = "x" * (Ratings::Rating::MAX_NOTES_LENGTH + 1)
    find('[role="tab"]', text: journal).click
    notes = find_field("notes")
    notes.execute_script("this.removeAttribute('maxlength')")
    notes.set(oversized_notes)
    click_button save
    assert_selector "#rating-errors"
    find('[role="tab"]', text: journal).click
    assert_field "notes", with: oversized_notes
    assert_button save, disabled: false
    fill_in "notes", with: "Revised notes"
    assert_button save, disabled: false
    fill_in "notes", with: "Original notes"
    assert_button save, disabled: true
    fill_in "notes", with: "Revised notes"
    click_button save
    assert_current_path library_path(view: "watched")
    assert_selector ".ui-toast", text: toast
    click_button I18n.t("library.browser.edit_film_rating", title: film.title)
    find('[role="tab"]', text: journal).click
    assert_field "notes", with: "Revised notes"
    assert_button save, disabled: true
  ensure
    browser&.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false)
  end

  private

  def tap_library_action(button)
    x, y = page.evaluate_script(<<~JS, button)
      ((button) => {
        button.scrollIntoView({ block: "nearest" })
        const rect = button.getBoundingClientRect()
        return [Math.round(rect.x + rect.width / 2), Math.round(rect.y + rect.height / 2)]
      })(arguments[0])
    JS
    browser = page.driver.browser
    browser.execute_cdp("Input.dispatchTouchEvent", type: "touchStart", touchPoints: [ { x:, y: } ])
    browser.execute_cdp("Input.dispatchTouchEvent", type: "touchEnd", touchPoints: [])
  end

  def assert_stacked_library_search(input_id)
    modes = find(".search-bar-modes").rect
    field = find("##{input_id}").rect
    tabs = find(".library-tabs").rect
    assert_operator modes.y + modes.height, :<=, field.y
    assert_operator field.y + field.height, :<=, tabs.y
    page_width = find(".library-page").rect.width
    [ modes, field, tabs ].each { |row| assert_in_delta 1, row.width.fdiv(page_width), 0.02 }
    [ ".search-bar-modes button", ".library-tabs a" ].each do |selector|
      first, second = all(selector, count: 2).map(&:rect)
      assert_equal first.y, second.y
      assert_in_delta first.width.fdiv(page_width), second.width.fdiv(page_width), 0.03
    end
  end

  def assert_poster_action_row
    poster = find(".film-poster").rect
    first_button, second_button = all(".library-card-actions .ui-action-button", count: 2).map(&:rect)
    assert_in_delta 4, first_button.y - (poster.y + poster.height), 1
    assert_in_delta first_button.width, second_button.width, 1
    assert_in_delta poster.x, first_button.x, 1
    assert_in_delta poster.x + poster.width, second_button.x + second_button.width, 1
  end

  def divider_position
    page.evaluate_script("document.querySelector('.library-collection-navigation').getBoundingClientRect().bottom")
  end
end
