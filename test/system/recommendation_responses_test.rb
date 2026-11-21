require "application_system_test_case"
require_relative "../support/assessed_recommendation_films"

class RecommendationResponsesTest < ApplicationSystemTestCase
  include AssessedRecommendationFilms

  test "navigation explains the lock on keyboard focus and unlocks after assessment" do
    visit recommendation_path
    click_button I18n.t("identity.entry.try_it_out")
    locked_link = find('.ui-nav [aria-describedby="recommendations-nav-tooltip"][aria-disabled="true"]')
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
    quality = quality_categories(:tone).qualities.create!(name: "Slow pace")
    4.times do |index|
      film = Registry::Film.create!(title: "Rated film #{index}")
      assess_recommendation_film(user:, film:, quality:)
    end
    pending_film = Registry::Film.create!(title: "Pending assessment")
    Registry::FilmQuality.create!(film: pending_film, quality:)
    rating = Ratings::RatingFilm.create!(user:, film: pending_film).submit_rating!(value: Ratings::Rating::Values::BRILLIANT)
    visit library_path
    assert_selector '.ui-nav [aria-describedby="recommendations-nav-tooltip"][aria-disabled="true"]'
    option = ".ui-primary-navigation option[value='#{recommendation_path}']"
    assert_selector "#{option}[disabled]", visible: :all

    apply_recommendation_assessment(rating:, quality:)
    assert_selector ".ui-nav a[href='#{recommendation_path}']", text: I18n.t("recommendations.title"), wait: 8
    assert_selector "#{option}:enabled", visible: :all, text: I18n.t("recommendations.title")
    assert_current_path library_path
  end

  test "the match and source links follow the title and wrap when needed" do
    film = Registry::Film.create!(title: "A recommendation with a match score", tmdb_id: 19_807, wikipedia_context: { page_id: 123 },
      tmdb_metadata: { details: { backdrop_path: "/still.jpg", overview: "A visitor arrives in a town where nobody goes out after dark." } })
    visit recommendation_path
    click_button I18n.t("identity.entry.try_it_out")
    assert_current_path recommendation_path
    user = Identity::Session.last.user

    qualities = 5.times.map { |index| quality_categories(:tone).qualities.create!(name: "Match quality #{index}") }
    qualities.each { |quality| Registry::FilmQuality.create!(film:, quality:) }
    8.times do |index|
      source = Registry::Film.create!(title: "Match source #{index}")
      qualities.each { |quality| Registry::FilmQuality.create!(film: source, quality:) }
      rating = Ratings::RatingFilm.create!(user:, film: source).submit_rating!(value: Ratings::Rating::Values::BRILLIANT)
      Ratings::QualityScoring::ScoreRatingQualities.call(rating_id: rating.id)
      Recommendations::RecommendationFilm.new(user:, film: source).suppress!
    end

    visit recommendation_path
    assert_selector "h2", text: film.title
    assert_selector ".film-synopsis[data-ready]"
    assert_no_button I18n.t("ui.synopsis.expand")
    backdrop = find('img.recommendation-backdrop[src="https://image.tmdb.org/t/p/w780/still.jpg"]')
    assert_no_selector ".recommendation-trailer, .recommendation-placeholder"
    score = find(".recommendation-match", text: I18n.t("recommendations.match.percentage", percentage: 65))
    mark = score.find('.recommendation-match-mark[aria-hidden="true"]')
    assert_includes mark.style("mask-image").fetch("mask-image"), "/glutton-mark.svg"
    assert_equal score.style("color").fetch("color"), mark.style("background-color").fetch("background-color")
    tooltip = "##{score["aria-describedby"]}"
    label = I18n.t("recommendations.match.label")
    assert_no_selector tooltip
    score.hover
    assert_selector tooltip, exact_text: label
    find(".recommendation-details h2").hover
    assert_no_selector tooltip
    score.send_keys(:shift)
    assert_selector tooltip, exact_text: label

    [ 1400, 390 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width:, height: 1000, deviceScaleFactor: 1, mobile: false)
      score_rect = score.rect
      title = find(".recommendation-heading h2").rect
      if width == 1400
        assert_operator score_rect.x, :>, title.x + title.width
        assert_in_delta title.y + title.height / 2.0, score_rect.y + score_rect.height / 2.0, 1
      else
        assert_in_delta title.x, score_rect.x, 1
        assert_operator score_rect.y, :>, title.y + title.height
      end
      [ "tmdb", "wikipedia" ].each do |source|
        link = find_link(I18n.t("registry.film_presentation.#{source}")).rect
        assert_in_delta score_rect.y + score_rect.height / 2.0, link.y + link.height / 2.0, 1
        assert_operator link.x, :>, score_rect.x + score_rect.width
      end
      synopsis = find(".film-synopsis-text").rect
      actions = find(".recommendation-actions").rect
      heading = find(".recommendation-heading").rect
      assert_in_delta 16.0 / 9, backdrop.rect.width.to_f / backdrop.rect.height, 0.02
      if width == 1400
        synopsis_area = find(".film-synopsis").rect
        assert_in_delta 12, actions.y - (heading.y + heading.height), 1
        assert_in_delta synopsis_area.y + synopsis_area.height, actions.y + actions.height, 1
        assert_in_delta synopsis_area.y, synopsis.y, 1
        assert_operator synopsis_area.height, :>, synopsis.height
        assert_operator actions.x, :>, synopsis_area.x + synopsis_area.width
      else
        assert_in_delta 12, synopsis.y - (heading.y + heading.height), 1
        assert_operator actions.y, :>, synopsis.y + synopsis.height
      end
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "expanding a trailer fills the card and keeps the same player" do
    film = Registry::Film.create!(title: "A recommendation with a trailer", tmdb_metadata: { details: {
      backdrop_path: "/still.jpg",
      overview: ("A visitor arrives in a town where nobody goes out after dark. " * 18).strip,
      videos: { results: [ { site: "YouTube", type: "Trailer", official: true, key: "M7lc1UVf-VE" } ] }
    } })
    password = "a long test password"
    user = Identity::UserRegistered.create!(email_address: "trailer-member@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current)
    unlock_recommendations_for(user:)
    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: user.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    visit account_settings_path
    page.execute_script("window.trailerTestStartedInAccount = true")
    within(".ui-nav") { click_link I18n.t("recommendations.title") }
    assert_current_path recommendation_path
    assert page.evaluate_script("window.trailerTestStartedInAccount")
    assert_selector "h2", text: film.title
    assert_selector ".recommendation-match", exact_text: I18n.t("recommendations.match.limited")

    player = find('#recommendation-trailer-player[referrerpolicy="strict-origin-when-cross-origin"]')
    assert_no_selector ".recommendation-backdrop, .recommendation-placeholder"
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
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 900, height: 1000, deviceScaleFactor: 1, mobile: false)
    assert_no_button I18n.t("recommendations.collapse_trailer")
    poster = find(".recommendation-artwork .film-poster").rect
    details = find(".recommendation-details").rect
    synopsis = find(".film-synopsis").rect
    tablet_player = player.rect
    actions = find(".recommendation-actions").rect
    assert_in_delta poster.y, tablet_player.y, 1
    assert_in_delta details.x, tablet_player.x, 1
    assert_operator tablet_player.x + tablet_player.width, :<, poster.x
    assert_in_delta poster.height, tablet_player.height, 1
    assert_operator details.y, :>, poster.y + poster.height
    assert_in_delta details.x, synopsis.x, 1
    assert_operator actions.x, :>, synopsis.x + synopsis.width

    text = find(".film-synopsis-text")
    heading = find(".recommendation-heading").rect
    assert_in_delta 12, actions.y - (heading.y + heading.height), 1
    assert_in_delta synopsis.y + synopsis.height, actions.y + actions.height, 1
    assert_in_delta 2 * text.style("line-height").fetch("line-height").to_f, synopsis.height, 1
    expand_synopsis = find_button I18n.t("ui.synopsis.expand")
    assert_in_delta synopsis.y, expand_synopsis.rect.y + expand_synopsis.rect.height, 1
    assert_in_delta synopsis.x + synopsis.width, expand_synopsis.rect.x + expand_synopsis.rect.width, 1
    expand_synopsis.click
    collapse_synopsis = find_button(I18n.t("ui.synopsis.collapse")).rect
    assert_operator text.rect.y, :<, synopsis.y
    assert_in_delta synopsis.y + synopsis.height, text.rect.y + text.rect.height, 1
    assert_in_delta text.rect.y, collapse_synopsis.y + collapse_synopsis.height, 1
    assert_in_delta synopsis.x + synopsis.width, collapse_synopsis.x + collapse_synopsis.width, 1
    assert_equal actions, find(".recommendation-actions").rect
    text.send_keys(:escape)
    assert_equal find_button(I18n.t("ui.synopsis.expand")), page.evaluate_script("document.activeElement")

    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 850, deviceScaleFactor: 1, mobile: true)
    assert_no_button I18n.t("recommendations.expand_trailer")
    assert_button I18n.t("recommendations.accept")
    watched = find_button I18n.t("library.detail.add_to_watched")
    assert_empty watched.text
    watched.assert_selector "svg"
    assert_selector "#recommendation-trailer-player[allowfullscreen]"
    mobile_player = player.rect
    poster = find(".recommendation-artwork .film-poster").rect
    details = find(".recommendation-details").rect
    actions = find(".recommendation-actions").rect
    assert_in_delta 16.0 / 9, mobile_player.width.to_f / mobile_player.height, 0.02
    assert_operator poster.y, :>, mobile_player.y + mobile_player.height
    assert_operator details.y, :>, poster.y + poster.height
    synopsis = find(".film-synopsis").rect
    assert_operator actions.y, :>, synopsis.y + synopsis.height
    assert_no_button I18n.t("ui.synopsis.expand")
    assert_equal "none", text.style("-webkit-line-clamp").fetch("-webkit-line-clamp")
    assert page.evaluate_script("arguments[0].clientHeight === arguments[0].scrollHeight", text)
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "cards keep proportional posters and right-aligned actions of the same size" do
    film = Registry::Film.create!(title: "Card sizing film")
    visit recommendation_path
    click_button I18n.t("identity.entry.try_it_out")
    assert_current_path recommendation_path
    unlock_recommendations_for(user: Identity::Session.last.user)

    [ 1400, 900, 390 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width:, height: 1000, deviceScaleFactor: 1, mobile: false)
      visit recommendation_path
      recommendation = find(".recommendation-film", text: film.title)
      assert_no_selector ".recommendation-trailer"
      within(recommendation) do
        placeholder = find(".recommendation-placeholder").rect
        poster = find(".recommendation-artwork .film-poster").rect
        assert_in_delta 16.0 / 9, placeholder.width.to_f / placeholder.height, 0.02
        if width > 650
          assert_in_delta placeholder.y, poster.y, 1
        else
          assert_operator poster.y, :>, placeholder.y + placeholder.height
        end
        assert_button I18n.t("library.detail.add_to_watched")
        assert_proportional_poster(".recommendation-artwork .film-poster")
        assert_actions_align_right(recommendation)
      end
      accept = find_button(I18n.t("recommendations.accept")).rect
      visit new_rating_path
      rating = find(".rating-interface", text: film.title)
      within(rating) do
        assert_selector '[role="tab"][aria-selected="true"]', text: I18n.t("ratings.browser.panels.rating")
        assert_proportional_poster(".rating-film-artwork .film-poster")
        assert_actions_align_right(rating)
        save = find_button(I18n.t("ratings.browser.save"), disabled: true).rect
        assert_in_delta accept.width, save.width, 1
        assert_in_delta accept.height, save.height, 1
      end
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

  private

  def assert_actions_align_right(card)
    actions = find(".film-actions").rect
    assert_in_delta card.rect.x + card.rect.width, actions.x + actions.width, 1
  end

  def assert_proportional_poster(selector)
    poster = find(selector).rect
    assert_in_delta poster.width * 1.5, poster.height, 1
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
  end
end
