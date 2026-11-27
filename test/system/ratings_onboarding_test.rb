require "application_system_test_case"
require_relative "../support/assessed_recommendation_films"

class RatingsOnboardingTest < ApplicationSystemTestCase
  include AssessedRecommendationFilms

  test "leaving the picker for the regular queue discards the selection" do
    first = Registry::Film.create!(title: "Regular candidate")
    chosen = Registry::Film.create!(title: "Unconfirmed film")
    visit new_rating_path
    click_button I18n.t("identity.entry.try_it_out")
    choose = find_button(I18n.t("ratings.onboarding.choose"))
    surprise = find_button(I18n.t("ratings.onboarding.surprise"))
    assert_in_delta 132, element_rectangle(choose).width, 1
    assert_in_delta element_rectangle(choose).width, element_rectangle(surprise).width, 1
    assert_in_delta 8, element_rectangle(surprise).x - (element_rectangle(choose).x + element_rectangle(choose).width), 1
    border = choose.style("border-top-width", "border-top-style", "border-top-color")
    assert_equal "1px", border.fetch("border-top-width")
    assert_equal "solid", border.fetch("border-top-style")
    choose.click

    find("input[type=checkbox][value='#{chosen.id}']").check
    start = find_button(I18n.t("ratings.onboarding.start"), disabled: true)
    back = find_button(I18n.t("ratings.onboarding.cancel"))
    assert_in_delta 132, element_rectangle(start).width, 1
    assert_in_delta element_rectangle(start).width, element_rectangle(back).width, 1
    assert_in_delta 8, element_rectangle(back).x - (element_rectangle(start).x + element_rectangle(start).width), 1
    assert_equal border, back.style(*border.keys)
    back.click
    assert_selector "h2", text: first.title
    assert_equal first, Ratings::RatingFilm.sole.film
    refresh
    assert_selector "h2", text: first.title
    assert_equal border, find_button(I18n.t("ratings.browser.dismiss")).style(*border.keys)

    unlock_recommendations_for(user: Identity::Session.last.user)
    visit recommendation_path
    assert_equal border, find_button(I18n.t("recommendations.reject")).style(*border.keys)
  end

  test "scrolling loads the next ranked batch and preserves selections" do
    first = Registry::Film.create!(title: "Z first", tmdb_metadata: { details: { vote_count: 50 } })
    middle = Array.new(23) { |index| Registry::Film.create!(title: "Middle #{index}", tmdb_metadata: { details: { vote_count: 10 } }) }
    last = Registry::Film.create!(title: "A last")
    open_picker

    actions = find(".rating-picker-actions")
    initial_border = actions.style("border-bottom-color")
    assert_equal first.title, first(".rating-film-choice-title").text
    assert_no_selector "input[value='#{last.id}']", visible: :all
    selected = [ first ] + middle.first(3)
    selected.each { |film| find("input[type=checkbox][value='#{film.id}']").check }
    assert_selector "#rating-picker-instructions", text: "Select at least 5 films to rate."
    start = find_button(I18n.t("ratings.onboarding.start"), disabled: true)
    assert_equal({ "cursor" => "not-allowed", "pointer-events" => "auto" }, start.style("cursor", "pointer-events"))
    assert_equal 0, Ratings::RatingFilm.count
    scroll_to(find("#rating-catalogue-2", visible: :all))
    find("input[type=checkbox][value='#{last.id}']").check
    assert_selector "input[type=checkbox]:checked", count: 5
    options = all(".rating-film-option", count: 25)
    assert_equal element_rectangle(options[23]).y, element_rectangle(options[24]).y
    assert_operator element_rectangle(options[24]).x, :>, element_rectangle(options[23]).x
    assert_in_delta 0, page.evaluate_script("document.querySelector('.rating-picker-actions').getBoundingClientRect().top"), 1
    assert_selector ".rating-picker-actions[data-stuck]"
    assert_not_equal initial_border, actions.style("border-bottom-color")
    click_button I18n.t("ratings.onboarding.start")

    assert_selector "h2", text: first.title
    assert_equal (selected + [ last ]).map(&:id), Ratings::RatingFilm.order(:id).pluck(:film_id)
  end

  private

  def open_picker
    visit new_rating_path
    click_button I18n.t("identity.entry.try_it_out")
    click_button I18n.t("ratings.onboarding.choose")
  end
end
