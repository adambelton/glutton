require "application_system_test_case"
require_relative "../support/assessed_recommendation_films"

class LibraryCandidateShortcutsTest < ApplicationSystemTestCase
  include AssessedRecommendationFilms

  test "adding a rating candidate to Watchlist skips it for just the next selection" do
    first = Registry::Film.create!(title: "First rating candidate")
    second = Registry::Film.create!(title: "Second rating candidate")
    visit new_rating_path
    click_button I18n.t("identity.entry.try_it_out")
    assert_selector "h2", text: first.title

    click_button I18n.t("library.detail.add_to_watchlist")
    assert_current_path new_rating_path
    assert_selector '[role="status"]', text: I18n.t("library.detail.watchlisted")
    assert_selector "h2", text: second.title
    assert_no_selector "h2", text: first.title
    library_film = Library::LibraryFilm.find_by!(film: first)
    assert_not library_film.watched?
    rating_film = Ratings::RatingFilm.find_by!(user: library_film.user, film: first)
    assert_not rating_film.dismissed?
    assert_not rating_film.suppressed?
    assert_empty rating_film.ratings

    visit new_rating_path
    assert_selector "h2", text: first.title
  end

  test "marking a recommendation Watched loads the next film before delivery" do
    first = Registry::Film.create!(title: "First recommendation")
    second = Registry::Film.create!(title: "Second recommendation")
    visit recommendation_path
    click_button I18n.t("identity.entry.try_it_out")
    assert_current_path recommendation_path
    assert_text "0 assessed so far"

    user = Identity::UserGuest.last
    unlock_recommendations_for(user:)

    visit recommendation_path
    assert_selector "h2", text: first.title
    click_button I18n.t("library.detail.add_to_watched")
    assert_current_path recommendation_path
    assert_selector '[role="status"]', text: I18n.t("library.detail.watched")
    assert_selector "h2", text: second.title
    assert_no_selector "h2", text: first.title
    assert_no_link href: new_rating_path(film_id: first.id)
    assert Library::LibraryFilm.find_by!(user:, film: first).watched?
    recommendation_film = Recommendations::RecommendationFilm.find_by!(user:, film: first)
    assert_not recommendation_film.suppressed?
    assert_nil recommendation_film.response

    visit recommendation_path
    assert_selector "h2", text: first.title

    DomainEvents::Delivery::Dispatch.call
    assert Ratings::RatingFilm.pending.exists?(user:, film: first)
  end
end
