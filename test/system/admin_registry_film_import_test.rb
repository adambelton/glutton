require "application_system_test_case"

class AdminRegistryFilmImportBrowserTest < ApplicationSystemTestCase
  setup do
    @forgery_protection = Registry::TmdbFilmSearchController.allow_forgery_protection
    Registry::TmdbFilmSearchController.allow_forgery_protection = true
  end

  teardown do
    Registry::TmdbFilmSearchController.allow_forgery_protection = @forgery_protection
  end

  test "the search bar switches between Registry filtering and TMDB results" do
    password = "a long test password"
    operator = Identity::UserRegistered.create!(email_address: "registry-search@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true)
    Registry::Film.create!(title: "Alien", tmdb_id: 348)
    catalogue_hits = (351..354).map do |id|
      title = "Related film #{id}"
      Registry::Film.create!(title:, tmdb_id: id)
      { "id" => id, "title" => title }
    end
    tmdb_client = Registry::Sources::TmdbClient
    original_search = tmdb_client.method(:search)
    tmdb_client.define_singleton_method(:search) do |query:, page:, primary_release_year:|
      pages = {
        1 => [
          { "id" => 348, "title" => "Alien" }, { "id" => 349, "title" => "Alien documentary", "genre_ids" => [ 99 ] },
          *catalogue_hits, { "id" => 355, "title" => "Alien re-release" }
        ],
        2 => [ { "id" => 350, "title" => "Another Alien" } ]
      }
      results = query == "Alien" ? pages.fetch(page, []) : []
      { "page" => page, "total_pages" => 2, "total_results" => 8, "results" => results }
    end

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: operator.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    visit account_settings_path
    within(".ui-nav") { click_link I18n.t("admin.title") }
    click_link I18n.t("registry.categories")
    standalone_search = element_rectangle(find_field(I18n.t("admin.search.quality_categories")))
    click_link I18n.t("registry.films")
    local_search = element_rectangle(find_field("Search films"))
    modes = element_rectangle(find(".search-bar-modes"))
    assert_in_delta standalone_search.width, local_search.width, 1
    assert_equal standalone_search.height, local_search.height
    assert_operator modes.x, :>, local_search.x + local_search.width
    registry_mode, tmdb_mode = all(".search-bar-modes button", count: 2).map { |button| element_rectangle(button) }
    assert_in_delta registry_mode.width, tmdb_mode.width, 1
    assert_no_field "Search TMDB"
    fill_in "Search films", with: "Related"
    assert_selector "tbody tr", count: 4
    click_link "Clear search"
    assert_current_path admin_films_path
    assert_selector "tbody tr", count: 5
    fill_in "Search films", with: "Alien"
    assert_current_path admin_films_path(q: "Alien")
    assert_selector "tbody tr", count: 1
    table_top = element_rectangle(find(".admin-table")).y
    click_button I18n.t("ui.search.tmdb")
    assert_no_field "Search films"
    tmdb_search = element_rectangle(find_field("Search TMDB"))
    assert_in_delta standalone_search.width, tmdb_search.width, 1
    assert_equal standalone_search.height, tmdb_search.height
    assert_equal table_top, element_rectangle(find(".admin-table")).y
    fill_in "Search TMDB", with: "Alien"

    within("#admin-tmdb-film-results") do
      assert_selector "h2", text: "Search results"
      assert_selector "li", count: 5
      assert_equal 0, find(".film-search-content").evaluate_script("this.scrollHeight - this.clientHeight")
      assert_text "Alien documentary"
      assert_text "In Registry"
      assert_button "Add to Registry", count: 1
      registry_link = find_link("Alien is in the Registry. View film")
      assert_equal "1px", registry_link.style("border-left-width").fetch("border-left-width")
      assert_equal element_rectangle(registry_link).width, element_rectangle(find_button("Add to Registry")).width
      within find("li", text: "Alien documentary") do
        assert_selector ".poster-wordmark", text: I18n.t("ui.short_wordmark")
        assert_selector 'h3 a[href="https://www.themoviedb.org/movie/349"][target="_blank"][rel~="noopener"]', text: "Alien documentary"
        title = element_rectangle(find("h3"))
        action = element_rectangle(find_button("Add to Registry"))
        assert_operator action.x, :>=, title.x + title.width
      end
      assert_short_dropdown
      click_link "Next page"
      assert_selector "li", count: 2
      assert_text "Alien re-release"
      click_link "Next page"
      assert_selector "li", count: 1
      assert_text "Another Alien"
      assert_no_link "Next page"
      click_link "Previous page"
      assert_selector "li", count: 2
      assert_text "Alien re-release"
    end
    assert_equal table_top, element_rectangle(find(".admin-table")).y
    assert_current_path admin_films_path(q: "Alien")
    assert_selector "tbody tr", count: 1
    click_link "Clear TMDB search"
    assert_field "Search TMDB", with: ""
    assert_no_selector ".admin-tmdb-results"
    click_button I18n.t("registry.films")
    assert_field "Search films", with: "Alien"
    click_button I18n.t("ui.search.tmdb")

    fill_in "Search TMDB", with: "Alien"
    within("#admin-tmdb-film-results") do
      assert_selector "li", count: 5
      click_link "Next page"
      assert_text "Alien re-release"
    end
    Registry::Film.create!(title: "Alien re-release", tmdb_id: 355)
    click_button I18n.t("registry.films")
    fill_in "Search films", with: "re-release"
    assert_current_path admin_films_path(q: "re-release")
    click_button I18n.t("ui.search.tmdb")
    click_button "Add to Registry"
    assert_current_path admin_films_path(q: "re-release")
    assert_selector ".admin-alert", exact_text: I18n.t("admin.tmdb.already_present")
    assert_selector "tbody tr", text: "Alien re-release", count: 1
    assert_field "Search films", with: "re-release"
    click_button I18n.t("ui.search.tmdb")
    assert_field "Search TMDB", with: ""
    assert_no_selector ".admin-tmdb-results"
    fill_in "Search TMDB", with: "Alien"
    within("#admin-tmdb-film-results") do
      click_link "Next page"
      assert_link "Alien re-release is in the Registry. View film"
      assert_no_button "Add to Registry"
    end
    assert_table_stays_in_place_on_narrow_screen
  ensure
    tmdb_client.define_singleton_method(:search, original_search) if original_search.present?
  end

  private

  def assert_table_stays_in_place_on_narrow_screen
    set_viewport(580, 1000)
    click_button I18n.t("registry.films")
    assert_field "Search films", with: "re-release"
    assert_no_selector ".admin-tmdb-results"
    table_top = element_rectangle(find(".admin-table")).y

    click_button I18n.t("ui.search.tmdb")
    assert_selector ".admin-tmdb-results li", count: 2
    assert_equal table_top, element_rectangle(find(".admin-table")).y
    modes = element_rectangle(find(".search-bar-modes"))
    assert_operator element_rectangle(find(".admin-tmdb-results")).y, :>=, modes.y + modes.height
  ensure
    reset_viewport
  end

  def assert_short_dropdown
    set_viewport(1400, 430)
    layout = page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      requestAnimationFrame(() => requestAnimationFrame(() => {
        const panel = document.querySelector(".admin-tmdb-results")
        const heading = panel.querySelector("h2")
        const rows = panel.querySelector(".film-search-content")
        const pagination = panel.querySelector("nav")
        const headingTop = heading.getBoundingClientRect().top
        const paginationTop = pagination.getBoundingClientRect().top
        rows.scrollTop = rows.scrollHeight
        done({
          rowsScrolled: rows.scrollTop > 0,
          headingStayed: heading.getBoundingClientRect().top === headingTop,
          paginationStayed: pagination.getBoundingClientRect().top === paginationTop,
          panelBottom: panel.getBoundingClientRect().bottom,
          viewportBottom: window.innerHeight
        })
      }))
    JS
    assert layout.fetch("rowsScrolled")
    assert layout.fetch("headingStayed")
    assert layout.fetch("paginationStayed")
    assert_operator layout.fetch("panelBottom"), :<=, layout.fetch("viewportBottom")
  ensure
    reset_viewport
  end
end
