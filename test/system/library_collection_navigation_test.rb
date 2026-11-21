require "application_system_test_case"

class LibraryCollectionNavigationTest < ApplicationSystemTestCase
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
      assert_no_selector "form[role=search] button"
    end

    assert_selector ".library-film-search-spinner"
    spinner = find(".library-film-search-spinner").rect
    field = find("#library-film-query").rect
    assert_operator spinner.x + spinner.width, :<=, field.x
    assert_selector ".library-film-search-dropdown h2", text: "Search results"
    assert_selector '.library-film-search-dropdown h3 a[href="https://www.themoviedb.org/movie/348"][target="_blank"][rel~="noopener"]',
      text: "Alien (1979)"
    assert_no_selector ".library-film-search-spinner"
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
      pagination = find(".library-pagination").rect
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
    within find(".film-search-results li", text: I18n.t("library.search.in_watchlist")) do
      assert_no_selector "button"
    end
    click_link I18n.t("library.browser.return")
    assert_selector ".library-film h3", text: "Alien"
  ensure
    client.define_singleton_method(:search, original_search)
  end

  test "local search filters the Library and the in-field clear restores the collection" do
    visit library_path
    click_button I18n.t("identity.entry.try_it_out")
    label = I18n.t("library.browser.search")
    assert_field label
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
  end

  test "Watched filters share the Watchlist divider position when they fit beside the tabs" do
    visit library_path
    click_button I18n.t("identity.entry.try_it_out")

    assert_selector ".library-tabs [aria-current='page']", text: I18n.t("library.browser.views.watchlist")
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

  test "Library ratings return to Watched with save feedback" do
    visit library_path
    click_button I18n.t("identity.entry.try_it_out")
    assert_current_path library_path
    user = Identity::UserGuest.last
    film = Registry::Film.create!(title: "Card action film")
    Library::CollectionManagement::AddToWatchlist.call(user_id: user.id, film_id: film.id)

    visit library_path
    within ".library-film" do
      assert_no_button "Rate #{film.title}"
      assert_button "Remove #{film.title} from watchlist"
      click_button "Mark #{film.title} watched"
    end

    assert_current_path new_rating_path(film_id: film.id)
    assert_selector "h2", text: film.title
    click_link I18n.t("library.browser.return")
    assert_current_path library_path(view: "watched")
    within ".library-film" do
      rating = find_button("Rate #{film.title}")
      move = find_button(I18n.t("library.detail.move_film_to_watchlist", title: film.title))
      assert_equal move.style("background-color"), rating.style("background-color")
      if page.evaluate_script("matchMedia('(hover: hover)').matches")
        page.evaluate_script("arguments[0].style.transition = arguments[1].style.transition = 'none'", move, rating)
        move.hover
        assert_selector "button:hover"
        hover_background = move.style("background-color")
        rating.hover
        assert_selector "button.library-rating-icon:hover"
        assert_equal hover_background, rating.style("background-color")
      end
      click_button "Rate #{film.title}"
    end
    assert_current_path new_rating_path(film_id: film.id)
    assert_selector "h2", text: film.title
    assert_link I18n.t("library.browser.return"), href: library_path(view: "watched")
    save = I18n.t("ratings.browser.save")
    journal = I18n.t("ratings.browser.panels.journal")
    toast = I18n.t("ratings.browser.saved")
    save_button = find_button(save, disabled: true).rect
    rating_card = find(".rating-interface").rect
    assert_in_delta rating_card.x + rating_card.width, save_button.x + save_button.width, 1
    find('label[for="rating-brilliant"]').click
    find('[role="tab"]', text: journal).click
    fill_in "notes", with: "Original notes"
    click_button save
    assert_current_path library_path(view: "watched")
    assert_selector ".ui-toast", text: toast

    click_button I18n.t("library.browser.edit_film_rating", title: film.title)
    assert_current_path edit_rating_path(film_id: film.id)
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
  end

  private

  def divider_position
    page.evaluate_script("document.querySelector('.library-collection-navigation').getBoundingClientRect().bottom")
  end
end
