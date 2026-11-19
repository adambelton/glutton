require "application_system_test_case"

class AdminRegistryFilmImportBrowserTest < ApplicationSystemTestCase
  test "the right-hand TMDB search updates and clears without leaving the catalogue" do
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
    within(".ui-nav") { assert_link "Admin" }
    visit admin_films_path
    fill_in "Search films", with: "Alien"
    assert_current_path admin_films_path(q: "Alien")
    assert_selector "tbody tr", count: 1
    assert_operator find_field("Search TMDB").rect.x, :>, find_field("Search films").rect.x
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
      assert_equal registry_link.rect.width, find_button("Add to Registry").rect.width
      within find("li", text: "Alien documentary") do
        poster = find(".poster-wordmark", text: I18n.t("ui.short_wordmark"))
        assert_equal [ 48, 72 ], [ poster.rect.width, poster.rect.height ]
        assert_match(/Tangerine/, poster.style("font-family").fetch("font-family"))
        assert_equal "34px", poster.style("font-size").fetch("font-size")
        assert_selector 'h3 a[href="https://www.themoviedb.org/movie/349"][target="_blank"][rel~="noopener"]', text: "Alien documentary"
        title = find("h3").rect
        action = find_button("Add to Registry").rect
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
    assert_current_path admin_films_path(q: "Alien")
    assert_selector "tbody tr", count: 1
    click_link "Clear TMDB search"
    assert_field "Search TMDB", with: ""
    assert_no_selector ".admin-tmdb-results"
    assert_field "Search films", with: "Alien"

    fill_in "Search TMDB", with: "Alien"
    within("#admin-tmdb-film-results") do
      assert_selector "li", count: 5
      click_link "Next page"
      assert_text "Alien re-release"
    end
    Registry::Film.create!(title: "Alien re-release", tmdb_id: 355)
    fill_in "Search films", with: "re-release"
    assert_current_path admin_films_path(q: "re-release")
    click_button "Add to Registry"
    assert_text I18n.t("admin.tmdb.already_present")
    assert_current_path search_admin_films_path(q: "re-release", tmdb_query: "Alien", tmdb_page: 1, tmdb_batch: 2)
    assert_selector "tbody tr", text: "Alien re-release", count: 1
    within("#admin-tmdb-film-results") do
      assert_selector "li", count: 2
      assert_link "Alien re-release is in the Registry. View film"
      assert_no_button "Add to Registry"
    end
  ensure
    tmdb_client.define_singleton_method(:search, original_search) if original_search.present?
  end

  private

  def assert_short_dropdown
    window = current_window
    width, height = window.size
    window.resize_to(width, 430)
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
    window.resize_to(width, height)
  end
end
