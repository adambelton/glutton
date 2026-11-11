require "application_system_test_case"

class LibraryCandidateShortcutsTest < ApplicationSystemTestCase
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
    quality = quality_categories(:tone).qualities.create!(name: "Slow pace")
    5.times { |index| assess_film(user:, quality:, index:) }

    visit recommendation_path
    assert_selector "h2", text: first.title
    click_button I18n.t("library.detail.mark_watched")
    assert_current_path recommendation_path
    assert_selector '[role="status"]', text: I18n.t("library.detail.watched")
    assert_selector "h2", text: second.title
    assert_no_selector "h2", text: first.title
    assert_link I18n.t("recommendations.rate_watched"), href: new_rating_path(film_id: first.id)
    assert Library::LibraryFilm.find_by!(user:, film: first).watched?
    assert_not Recommendations::RecommendationFilm.exists?(user:, film: first)

    visit recommendation_path
    assert_selector "h2", text: first.title
  end

  private

  def assess_film(user:, quality:, index:)
    film = Registry::Film.create!(title: "Rated film #{index}")
    Registry::FilmQuality.create!(film:, quality:)
    rating_film = Ratings::RatingFilm.create!(user:, film:)
    rating = rating_film.submit_rating!(value: Ratings::Rating::Values::BRILLIANT)
    evaluation = Ratings::RatingQualityEval.create!(rating:, input: [], output: {
      notes: {}, qualities: { quality.id.to_s => { name: quality.name, match_rule: nil, not_sufficient: nil } },
      calls: [], decisions: [ { quality_id: quality.id, applicable: false, supporting_rating_ids: [], result_ids: [] } ]
    })
    rating.apply_quality_evaluation!(evaluation:)
    Recommendations::RecommendationFilm.new(user:, film:).suppress!
  end
end
