require "application_system_test_case"
require_relative "../support/assessed_recommendation_films"

class RecommendationResponsesTest < ApplicationSystemTestCase
  include AssessedRecommendationFilms

  test "navigation explains the lock on keyboard focus and unlocks after assessment" do
    visit recommendation_path
    click_button I18n.t("identity.entry.try_it_out")
    locked_link = find('.ui-nav [role="link"][aria-disabled="true"]')
    assert_no_link I18n.t("recommendations.title")
    locked_link.send_keys(:shift)
    tooltip = find('[role="tooltip"]', text: I18n.t("recommendations.navigation_locked", required: 5))
    assert page.evaluate_script(<<~JS, tooltip, locked_link)
      ((tooltip, link) => {
        const label = document.createRange()
        label.selectNode(link.firstChild)
        const bounds = tooltip.getBoundingClientRect()
        return bounds.top >= 0 && bounds.bottom < label.getBoundingClientRect().top
      })(arguments[0], arguments[1])
    JS

    assert page.evaluate_script(<<~JS, tooltip)
      ((tooltip) => {
        for (let element = tooltip; element; element = element.parentElement) {
          if (getComputedStyle(element).opacity !== "1") return false
        }
        return getComputedStyle(tooltip).backgroundColor === getComputedStyle(document.body).color
      })(arguments[0])
    JS

    user = Identity::Session.last.user
    pending_film = Registry::Film.create!(title: "Pending assessment")
    Ratings::RatingFilm.create!(user:, film: pending_film).submit_rating!(value: Ratings::Rating::Values::BRILLIANT)
    visit library_path
    assert_selector '.ui-nav [role="link"][aria-disabled="true"]'

    unlock_recommendations_for(user:)
    visit library_path
    assert_link I18n.t("recommendations.title"), href: recommendation_path
  end

  test "expanding a trailer fills the card and keeps the same player" do
    film = Registry::Film.create!(title: "A recommendation with a trailer", tmdb_metadata: { details: {
      videos: { results: [ { site: "YouTube", type: "Trailer", official: true, key: "M7lc1UVf-VE" } ] }
    } })
    visit recommendation_path
    click_button I18n.t("identity.entry.try_it_out")
    assert_current_path recommendation_path
    unlock_recommendations_for(user: Identity::Session.last.user)
    visit recommendation_path
    assert_selector "h2", text: film.title

    player = find("#recommendation-trailer-player")
    original_width = player.rect.width
    original_height = find(".recommendation-film").rect.height
    expand = find_button(I18n.t("recommendations.expand_trailer"))
    assert_in_delta player.rect.x + original_width + 12, expand.rect.x + expand.rect.width, 1
    assert_in_delta player.rect.y + player.rect.height + 12, expand.rect.y + expand.rect.height, 1
    expand.click
    assert_button I18n.t("recommendations.collapse_trailer")
    assert_no_button I18n.t("recommendations.accept")
    frame = find(".recommendation-trailer-frame").rect
    card = find(".recommendation-film").rect
    expanded_player = player.rect
    assert_in_delta 16.0 / 9, expanded_player.width.to_f / expanded_player.height, 0.01
    assert_in_delta card.x + card.width / 2.0, expanded_player.x + expanded_player.width / 2.0, 1
    assert_in_delta card.y + card.height / 2.0, expanded_player.y + expanded_player.height / 2.0, 1
    assert_in_delta [ card.width, card.height * 16.0 / 9 ].min, expanded_player.width, 1
    assert_in_delta original_height, find(".recommendation-film").rect.height, 1
    collapse = find_button(I18n.t("recommendations.collapse_trailer"))
    assert_operator collapse.rect.x, :<, frame.x + frame.width
    assert_operator collapse.rect.y, :<, frame.y + frame.height
    assert_operator collapse.rect.x + collapse.rect.width, :>, frame.x + frame.width
    assert_operator collapse.rect.y + collapse.rect.height, :>, frame.y + frame.height
    assert_operator player.rect.width, :>, original_width

    collapse.send_keys(:escape)
    assert_button I18n.t("recommendations.expand_trailer")
    assert_button I18n.t("recommendations.accept")
    assert_in_delta original_width, player.rect.width, 1
    assert page.evaluate_script("arguments[0] === document.querySelector('#recommendation-trailer-player')", player)

    click_button I18n.t("recommendations.expand_trailer")
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 850, deviceScaleFactor: 1, mobile: true)
    assert_no_button I18n.t("recommendations.collapse_trailer")
    assert_no_button I18n.t("recommendations.expand_trailer")
    assert_button I18n.t("recommendations.accept")
    assert_selector "#recommendation-trailer-player[allowfullscreen]"
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "rating and recommendation cards and posters use matching dimensions" do
    film = Registry::Film.create!(title: "Card sizing film")
    visit recommendation_path
    click_button I18n.t("identity.entry.try_it_out")
    assert_current_path recommendation_path
    unlock_recommendations_for(user: Identity::Session.last.user)

    [ 1400, 900, 390 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width:, height: 1000, deviceScaleFactor: 1, mobile: false)
      visit recommendation_path
      recommendation = find(".ui-card", text: film.title).rect
      recommendation_poster = find(".recommendation-artwork .film-poster").rect
      visit new_rating_path
      rating = find(".ui-card", text: film.title).rect
      rating_poster = find(".rating-film-artwork .film-poster").rect
      assert_in_delta rating.height, recommendation.height, 1
      assert_in_delta rating_poster.width, recommendation_poster.width, 1
      assert_in_delta rating_poster.height, recommendation_poster.height, 1
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "new ratings leave a queued recommendation in place until a response" do
    first = Registry::Film.create!(title: "A recommendation to accept")
    second = Registry::Film.create!(title: "A recommendation to reject")
    third = Registry::Film.create!(title: "Next recommendation")
    visit recommendation_path
    click_button I18n.t("identity.entry.try_it_out")
    assert_current_path recommendation_path

    user = Identity::Session.last.user
    unlock_recommendations_for(user:)
    visit recommendation_path
    assert_selector "h2", text: first.title
    queued = Recommendations::RecommendationFilm.find_by!(user:, film: first)
    assert_predicate queued.recommended_at, :present?

    visit new_rating_path
    quality = quality_categories(:tone).qualities.create!(name: "Quiet scenes")
    Registry::FilmQuality.create!(film: second, quality:)
    evidence = Registry::Film.create!(title: "Newly assessed film")
    assess_recommendation_film(user:, film: evidence, quality:)
    assert_equal second, Recommendations::CandidateSelection::NextCandidate.call(user_id: user.id).film

    visit recommendation_path
    assert_selector "h2", text: first.title
    assert_equal queued.recommended_at, queued.reload.recommended_at

    click_button I18n.t("recommendations.accept")
    assert_current_path recommendation_path
    assert_selector '[role="status"]', text: I18n.t("recommendations.responses.accepted")
    assert_selector "h2", text: second.title
    assert_equal "accepted", Recommendations::RecommendationFilm.find_by!(user:, film: first).response

    click_button I18n.t("recommendations.reject")
    assert_current_path recommendation_path
    assert_no_selector '[role="status"]'
    assert_selector "h2", text: third.title
    assert_equal "rejected", Recommendations::RecommendationFilm.find_by!(user:, film: second).response

    accepted = DomainEvents::DomainEvent.where(name: Recommendations::Events::RECOMMENDATION_ACCEPTED).sole
    assert_equal first.id, accepted.payload.fetch("film_id")
    assert_not Library::LibraryFilm.exists?(user:, film: first)
  end
end
