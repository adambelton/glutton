require "application_system_test_case"

class SuperuserUserAdministrationBrowserTest < ApplicationSystemTestCase
  test "a superuser opens a user, follows the profile link and revokes a session" do
    password = "a long test password"
    operator = Identity::UserRegistered.create!(email_address: "support@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true)
    guest = Identity::UserGuest.create!
    authentication = Identity::Session.create!(user: guest)
    long_title = "Matched film 00 #{"with an unusually long title " * 10}"
    Registry::Film.create!(title: long_title)
    1.upto(10) { |number| Registry::Film.create!(title: "Matched film %02d" % number) }
    category = Registry::QualityCategory.create!(name: "Test category", maximum_qualities: 1)
    Registry::Quality.create!(name: "Atmospheric", quality_category: category)
    Registry::Quality.create!(name: "Unsettling", quality_category: quality_categories(:tone))
    detail_path = admin_user_path(guest.id)
    profile_path = glutton_profile_admin_user_path(guest.id)

    visit new_session_path
    page.execute_script("localStorage.setItem('glutton.theme', 'dark'); document.documentElement.removeAttribute('data-theme')")
    assert_equal "dark", page.evaluate_script("getComputedStyle(document.documentElement).colorScheme")
    fill_in I18n.t("identity.sessions.email"), with: operator.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    within(".ui-nav") { click_link "Admin" }
    assert_current_path admin_users_path
    assert_sidebar_layout
    assert_equal "light", page.evaluate_script("getComputedStyle(document.documentElement).colorScheme")
    assert_selector ".admin-sidebar > a.admin-wordmark:first-child[href='#{library_path}']", text: "glutton."
    assert_collection_dimensions
    fill_in "Search by user ID or email address", with: guest.id
    assert_selector "tbody tr", count: 1
    assert_link "User ##{guest.id}"
    assert_current_path admin_users_path
    assert_selector "#admin-collection-query:focus"
    assert_collection_dimensions
    click_link "Clear search"
    assert_selector "tbody tr", count: 2
    within(".admin-navigation") { click_link "Films" }
    assert_current_path admin_films_path
    fill_in "Search films", with: "matched"
    assert_current_path admin_films_path(q: "matched")
    assert_selector "tbody tr", count: 10
    assert_collection_dimensions
    long_cell = find("tbody tr:first-child td:first-child .ui-table-cell", text: "Matched film 00")
    assert_equal "2", long_cell.style("-webkit-line-clamp").fetch("-webkit-line-clamp")
    assert long_cell.evaluate_script("this.scrollHeight > this.clientHeight")
    line_height = long_cell.style("line-height").fetch("line-height").to_f
    assert_in_delta 2 * line_height, element_rectangle(long_cell).height, 1
    click_link "Next page"
    assert_current_path admin_films_path(page: 2, q: "matched")
    assert_selector "tbody tr", count: 1
    click_link "Clear search"
    assert_current_path admin_films_path
    within(".admin-navigation") { click_link "Qualities" }
    assert_current_path admin_qualities_path
    assert_collection_dimensions
    fill_in "Search qualities", with: "Atmospheric"
    assert_selector "tbody tr", count: 1
    assert_link "Atmospheric"
    fill_in "Search qualities", with: ""
    assert_current_path admin_qualities_path
    assert_selector "tbody tr", count: 2
    within(".admin-navigation") { click_link "Quality categories" }
    assert_current_path admin_quality_categories_path
    assert_collection_dimensions
    fill_in "Search quality categories", with: "Test category"
    assert_selector "tbody tr", count: 1
    assert_link "Test category"
    find_field("Search quality categories").send_keys(:escape)
    assert_field "Search quality categories", with: ""
    assert_current_path admin_quality_categories_path
    assert_selector "tbody tr", minimum: 2
    within(".admin-navigation") { click_link "Users" }
    assert_current_path admin_users_path

    within("tbody") { click_link "User ##{guest.id}" }
    assert_current_path detail_path
    assert_selector "main > a.admin-back + h1", text: "User #{guest.id}"
    click_link "View Glutton Profile"
    assert_current_path profile_path
    assert_text "No saved claims and evidence for this profile."

    click_link "Back to user"
    assert_current_path detail_path
    click_button "Revoke session #{authentication.id}"
    assert_text "Session revoked."
    assert_text "No stored sessions."
    refute authentication.active?

    set_viewport(420, 900)
    visit library_path
    select "Admin", from: I18n.t("ui.navigation")
    assert_current_path admin_users_path
    assert_sidebar_layout
    assert_equal "light", page.evaluate_script("getComputedStyle(document.documentElement).colorScheme")
    assert_collection_dimensions
    assert_selector ".user-created-inline time", text: I18n.l(guest.created_at.to_date, format: :user_admin)
    assert_link "User ##{guest.id}"
    click_link "Back to Glutton"
    assert_current_path library_path
    assert_equal "dark", page.evaluate_script("getComputedStyle(document.documentElement).colorScheme")
  ensure
    reset_viewport
  end

  private

  def assert_collection_dimensions
    assert_selector "input[type=search][placeholder][aria-label]"
    assert_no_selector ".admin-search button"
    dimensions = page.evaluate_script(<<~JS)
      (() => {
        const input = document.querySelector(".collection-search-field input").getBoundingClientRect()
        const clearLink = document.querySelector(".collection-search-clear:not([hidden])")
        const clear = clearLink?.getBoundingClientRect()
        return {
          inputHeight: input.height,
          rows: [...document.querySelectorAll(".admin-table tr")].map((row) => row.getBoundingClientRect().height),
          paginationBorder: getComputedStyle(document.querySelector(".admin-pagination")).borderBlockStartWidth,
          lastRowBorder: getComputedStyle(document.querySelector(".admin-table tbody tr:last-child td")).borderBlockEndWidth,
          clearInside: !clear || (clear.left >= input.left && clear.right <= input.right &&
            clear.top >= input.top && clear.bottom <= input.bottom)
        }
      })()
    JS
    assert_equal 46, dimensions.fetch("inputHeight")
    assert dimensions.fetch("clearInside")
    assert_equal [ 56 ], dimensions.fetch("rows").uniq
    assert_equal "0px", dimensions.fetch("paginationBorder")
    assert_equal "1px", dimensions.fetch("lastRowBorder")
  end

  def assert_sidebar_layout
    assert_selector "body.admin-page > .admin-sidebar"
    assert page.evaluate_script(<<~JS)
      (() => {
        const navigation = document.querySelector(".admin-sidebar").getBoundingClientRect()
        const content = document.querySelector("#main-content").getBoundingClientRect()
        const layout = document.body.getBoundingClientRect()
        return navigation.right <= content.left && navigation.top === 0 &&
          navigation.bottom >= window.innerHeight - 1 && Math.abs(content.right - layout.right) <= 1
      })()
    JS
  end
end
