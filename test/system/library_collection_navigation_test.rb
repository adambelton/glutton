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

  test "Watchlist card controls mark a film watched and open its rating form" do
    visit library_path
    click_button I18n.t("identity.entry.try_it_out")
    assert_current_path library_path
    user = Identity::UserGuest.last
    film = Registry::Film.create!(title: "Card action film")
    Library::CollectionManagement::AddToWatchlist.call(user_id: user.id, film_id: film.id)

    visit library_path
    within ".library-film" do
      assert_no_link "Rate #{film.title}"
      assert_button "Remove #{film.title} from watchlist"
      click_button "Mark #{film.title} watched"
    end

    assert_current_path library_path(view: "watched")
    within ".library-film" do
      assert_selector 'a[data-tooltip="Add rating"]'
      click_link "Rate #{film.title}"
    end
    assert_current_path new_rating_path(film_id: film.id)
    assert_selector "h2", text: film.title
  end

  private

  def divider_position
    page.evaluate_script("document.querySelector('.library-collection-navigation').getBoundingClientRect().bottom")
  end
end
