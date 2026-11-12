require "application_system_test_case"

class LibraryCollectionNavigationTest < ApplicationSystemTestCase
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
  end

  private

  def divider_position
    page.evaluate_script("document.querySelector('.library-collection-navigation').getBoundingClientRect().bottom")
  end
end
