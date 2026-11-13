require "application_system_test_case"

class LibraryCollectionNavigationTest < ApplicationSystemTestCase
  test "film search from the Library heading adds a result to Watchlist" do
    client = Registry::Sources::TmdbClient
    original_search = client.method(:search)
    client.define_singleton_method(:search) do |query:, page:, **|
      sleep 0.4
      results = (page == 1 ? 7 : 5).times.map do |index|
        { "id" => 348 + index, "title" => (page == 1 && index.zero? ? query : "#{query} #{page}-#{index + 1}"),
          "release_date" => "1979-05-25", "poster_path" => ("/alien.jpg" unless index == 6), "genre_ids" => [ 27 ],
          "overview" => "A crew answers a distress signal on a distant moon." }
      end
      { "page" => page, "total_pages" => 2, "total_results" => 12, "results" => results }
    end
    Registry::Film.create!(title: "Alien", tmdb_id: 348)

    visit library_path
    click_button I18n.t("identity.entry.try_it_out")
    heading = find(".ui-page-heading h1").rect
    search_field = find("#library-film-query").rect
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
    assert_selector ".library-film-search-dropdown h3", text: "Alien (1979)"
    assert_no_selector ".library-film-search-spinner"
    assert_selector ".library-film-search-dropdown img[src$='/alien.jpg']"
    assert_selector ".library-film-search-dropdown .library-film-search-overview", count: 5,
      text: "A crew answers a distress signal"
    assert_selector ".library-film-search-dropdown button[aria-label='Mark watched'] svg"
    actions = first(".library-film-search-actions").rect
    details = first(".library-film-search-result-details").rect
    assert_operator actions.x, :>=, details.x + details.width
    assert_selector "#library-film-query:focus"
    assert_current_path library_path
    within ".library-film-search-dropdown" do
      assert_selector "li", count: 5
      assert_text "Page 1 of 2"
      assert_selector "h3 .film-year", text: "(1979)", count: 5
      last_result = all("li", count: 5).last.rect
      pagination = find(".library-pagination").rect
      assert_operator last_result.y + last_result.height, :<=, pagination.y
      click_link I18n.t("library.browser.next")
      assert_selector "li", count: 2
      assert_text "Alien 1-7"
      poster = find("img.film-poster").rect
      within all("li", count: 2).last do
        placeholder = find(".film-poster.poster-wordmark", text: I18n.t("ui.short_wordmark")).rect
        assert_equal [ poster.width, poster.height ], [ placeholder.width, placeholder.height ]
        assert_selector ".library-film-search-overview", text: "A crew answers a distress signal"
      end
      click_link I18n.t("library.browser.next")
      assert_text "Alien 2-5"
      assert_current_path library_path
      click_link I18n.t("library.browser.previous")
      assert_text "Alien 1-7"
      click_link I18n.t("library.browser.previous")
      assert_selector "h3", text: "Alien (1979)", exact_text: true
      first("li").click_button I18n.t("library.detail.add_to_watchlist")
    end
    assert_text I18n.t("library.search.in_watchlist")
    click_link I18n.t("library.browser.return")
    assert_selector ".library-film h3", text: "Alien"
  ensure
    client.define_singleton_method(:search, original_search)
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
    find_button(I18n.t("ui.dark_mode")).send_keys(:enter)
    assert_selector 'html[data-theme="dark"]'
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

  test "Watchlist card controls mark a film watched and open its rating form" do
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
  end

  private

  def divider_position
    page.evaluate_script("document.querySelector('.library-collection-navigation').getBoundingClientRect().bottom")
  end
end
