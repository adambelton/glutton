require "application_system_test_case"

class CommunityCurationBrowserTest < ApplicationSystemTestCase
  test "searching Watched films builds a list with removable references and optional comments" do
    password = "a long test password"
    author = Identity::UserRegistered.create!(email_address: "curation-browser@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true,
      community_username: "Curator", community_avatar_preset: "moth",
      community_code_of_conduct_version: Community::CodeOfConduct.current.version,
      community_code_of_conduct_accepted_at: Time.current)
    [ "The Empty Field", "Folk Tales", "Ghost Ridge" ].each do |title|
      film = Registry::Film.create!(title:, tmdb_metadata: { details: { genres: [ { name: "Horror" } ] } })
      Library::LibraryFilm.new(user: author, film:).add_to_watched!
    end

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: author.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    visit community_path
    click_link I18n.t("community.curations.create")
    fill_in I18n.t("community.curations.title"), with: "Slow-burn modern folk horror"
    fill_in I18n.t("community.curations.description"), with: "Stories that take their time."

    search = I18n.t("community.curations.search_watched")
    assert_field search, placeholder: search
    heading = find(".community-reference-picker legend").rect
    guidance = find("#curation_reference_hint").rect
    search_field = find_field(search).rect
    assert_operator guidance.x, :>, heading.x
    assert_in_delta 8, search_field.y - (heading.y + heading.height), 1
    assert_no_text "The Empty Field"
    assert_no_text "Folk Tales"
    fill_in search, with: "empty"
    find_field(search).send_keys(:enter)
    assert_current_path new_community_curation_path
    assert_no_text "Folk Tales"
    click_button I18n.t("community.curations.add_film", title: "The Empty Field")
    assert_field search, with: ""
    assert_no_selector ".community-reference-films"
    within(".community-selected-films li", text: "The Empty Field") do
      assert_selector ".film-poster"
      fill_in I18n.t("community.curations.comment_for_film", title: "The Empty Field"), with: "A creeping sense of dread."
      assert_in_delta find(".film-poster").rect.height, find("textarea").rect.height, 1
    end
    fill_in search, with: "missing"
    assert_text I18n.t("community.curations.no_matches")
    fill_in search, with: "folk"
    click_button I18n.t("community.curations.add_film", title: "Folk Tales")
    fill_in I18n.t("community.curations.comment_for_film", title: "Folk Tales"), with: "The setting feels isolated."
    fill_in search, with: "ghost"
    click_button I18n.t("community.curations.add_film", title: "Ghost Ridge")
    fill_in I18n.t("community.curations.comment_for_film", title: "Ghost Ridge"), with: "Discard this comment."
    click_button I18n.t("community.curations.remove_film", title: "Ghost Ridge")
    assert_no_selector ".community-selected-films li", text: "Ghost Ridge"
    click_button I18n.t("community.curations.publish")

    assert_selector "h1", text: "Slow-burn modern folk horror"
    assert_selector "main.community-curation-page:not(.ui-narrow)"
    assert_selector ".community-post-tag", text: I18n.t("community.curations.tag")
    assert_no_text "A creeping sense of dread."
    assert_no_text "The setting feels isolated."
    within ".community-nominations-toolbar" do
      assert_text I18n.t("community.curations.endorsement_order")
      type_properties = [ "font-size", "font-weight", "color" ]
      ordering_style = find("p").style(*type_properties)
      expand = find_button(I18n.t("community.curations.expand_all"))
      collapse = find_button(I18n.t("community.curations.collapse_all"), disabled: true)
      assert_equal ordering_style, expand.style(*type_properties)
      assert_equal ordering_style, collapse.style(*type_properties)
      expand.click
    end
    assert_text "A creeping sense of dread."
    assert_text "The setting feels isolated."
    assert_button I18n.t("community.curations.expand_all"), disabled: true
    click_button I18n.t("community.curations.collapse_all")
    assert_no_text "A creeping sense of dread."
    assert_no_text "The setting feels isolated."
    assert_button I18n.t("community.curations.collapse_all"), disabled: true
    within find(".community-nomination", text: "The Empty Field") do
      assert_selector ".film-poster"
      assert_selector ".community-endorsement-badge", text: I18n.t("community.curations.endorsements", count: 1)
      assert_no_text "A creeping sense of dread."
      find("summary", text: I18n.t("community.curations.comments", count: 1)).click
      assert_text "A creeping sense of dread."
      assert_button I18n.t("community.curations.reply"), disabled: true
      assert_button I18n.t("community.curations.report"), disabled: true
    end
    assert_button I18n.t("community.curations.expand_all")
    assert_button I18n.t("community.curations.collapse_all")
    assert_no_text "The setting feels isolated."
    click_button I18n.t("community.curations.collapse_all")
    assert_no_text "A creeping sense of dread."
    assert_button I18n.t("community.curations.collapse_all"), disabled: true
    assert_selector ".community-nomination", text: /Folk Tales\s*1 endorsement/
    assert_no_text "Ghost Ridge"
    assert_no_text "Discard this comment."
  end

  test "a nomination uses the shared title and updates its Library icons below the poster" do
    password = "a long test password"
    author = Identity::UserRegistered.create!(email_address: "curation-library-author@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true,
      community_username: "Curator", community_avatar_preset: "moth",
      community_code_of_conduct_version: Community::CodeOfConduct.current.version,
      community_code_of_conduct_accepted_at: Time.current)
    viewer = Identity::UserRegistered.create!(email_address: "curation-library-reader@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true)
    film = Registry::Film.create!(title: "Folk Tales", tmdb_id: 123, release_date: Date.new(2020, 1, 1),
      tmdb_metadata: { details: { genres: [ { name: "Horror" } ] } })
    Library::LibraryFilm.new(user: author, film:).add_to_watched!
    curation = Community::PublishCuration.call(author_id: author.id, title: "Folk horror", prompt: "Films for this theme.",
      reference_film_ids: [ film.id ], reference_comments: {})

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: viewer.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    visit community_curation_path(curation)
    curation_dimensions = poster_action_dimensions
    within "#nomination-#{film.id}" do
      assert_selector ".community-nomination-rank", text: "1."
      assert_selector "h3", text: "Folk Tales (2020)"
      assert_selector "h3 .film-year", text: "(2020)"
      assert_no_selector "h3 a"
      poster = find(".film-poster").rect
      assert_in_delta 4, find(".community-nomination-actions").rect.y - (poster.y + poster.height), 1
      watchlist_button, watched_button = all(".library-card-actions .ui-action-button", count: 2).map(&:rect)
      assert_in_delta watchlist_button.width, watched_button.width, 1
      assert_in_delta poster.x, watchlist_button.x, 1
      assert_in_delta poster.x + poster.width, watched_button.x + watched_button.width, 1
      click_button I18n.t("library.detail.add_to_watchlist")
      watchlist_label = I18n.t("library.search.in_watchlist")
      assert_selector "button[data-in-collection=true][aria-disabled=true][aria-label='#{watchlist_label}'] svg"
    end
    assert_current_path community_curation_path(curation)
    assert Library::LibraryFilm.watchlist.exists?(user: viewer, film:)

    within "#nomination-#{film.id}" do
      click_button I18n.t("library.detail.add_to_watched")
      watched_label = I18n.t("library.search.in_watched")
      assert_selector "button[data-in-collection=true][aria-disabled=true][aria-label='#{watched_label}'] svg"
      watchlist_label = I18n.t("community.curations.watchlist_unavailable_when_watched")
      watchlist_icon = find("button[aria-disabled=true][aria-label='#{watchlist_label}']:not([data-in-collection])")
      assert_equal "0.45", watchlist_icon.find("svg").style("opacity").fetch("opacity")
      assert_equal "1", find("button[data-in-collection=true] svg").style("opacity").fetch("opacity")
      watchlist_icon.hover
      assert_equal "visible", watchlist_icon.evaluate_script("getComputedStyle(this, '::after').visibility")
    end
    assert Library::LibraryFilm.watched.exists?(user: viewer, film:)

    visit library_path(view: "watched")
    assert_text film.title
    assert_equal curation_dimensions, poster_action_dimensions
  end

  test "the board uses full-width post cards and shows fewer posters on a narrow screen" do
    password = "a long test password"
    author = Identity::UserRegistered.create!(email_address: "curation-board@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true,
      community_username: "Curator", community_avatar_preset: "moth",
      community_code_of_conduct_version: Community::CodeOfConduct.current.version,
      community_code_of_conduct_accepted_at: Time.current)
    films = 5.times.map do |index|
      film = Registry::Film.create!(title: "Folk horror #{index + 1}", tmdb_metadata: { details: { genres: [ { name: "Horror" } ] } })
      Library::LibraryFilm.new(user: author, film:).add_to_watched!
      film
    end
    curation = Community::PublishCuration.call(author_id: author.id, title: "Folk horror", prompt: "Isolated communities and older traditions.",
      reference_film_ids: films.map(&:id), reference_comments: { films.first.id => "An isolated setting." })
    shorter = Community::PublishCuration.call(author_id: author.id, title: "Two-film curation", prompt: "A narrower theme.",
      reference_film_ids: films.first(2).map(&:id), reference_comments: {})

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: author.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    visit community_path
    card = find(".community-curation-card", text: curation.title)
    shorter_card = find(".community-curation-card", text: shorter.title)
    assert_in_delta find(".community-curation-list").rect.width, card.rect.width, 1
    within card do
      assert_no_text curation.prompt
      assert_text I18n.t("community.curations.created")
      assert_text I18n.t("community.curations.updated")
      assert_selector "time", count: 2
      assert_selector ".community-curation-card-posters .film-poster", count: 5
      within ".community-curation-card-counts" do
        assert_text I18n.t("community.curations.films", count: 5)
        assert_text I18n.t("community.curations.endorsements", count: 5)
        assert_text I18n.t("community.curations.comments", count: 1)
      end
    end
    full_strip = card.find(".community-curation-card-posters").rect
    inner_width = card.evaluate_script(<<~JS)
      (() => {
        const style = getComputedStyle(this)
        return this.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight)
      })()
    JS
    assert_in_delta inner_width / 3.0, full_strip.width, 1
    title_margins = card.find("h2").evaluate_script("[getComputedStyle(this).marginBlockStart, getComputedStyle(this).marginBlockEnd]")
    assert_equal [ "0px", "0px" ], title_margins
    assert_in_delta full_strip.y, card.find(".community-curation-card-heading").rect.y, 1
    timestamps = card.find(".community-curation-card-timestamps")
    assert_operator timestamps.rect.y, :>=, full_strip.y + full_strip.height
    last_timestamp = timestamps.all(":scope > span", count: 2).last.rect
    assert_in_delta full_strip.x + full_strip.width, last_timestamp.x + last_timestamp.width, 1
    title = card.find("h2").rect
    byline = card.find(".community-curation-card-byline").rect
    counts = card.find("footer .community-curation-card-counts").rect
    assert_in_delta title.x, byline.x, 1
    assert_operator byline.y, :>=, title.y + title.height
    assert_in_delta full_strip.y + full_strip.height, byline.y + byline.height, 1
    assert_in_delta title.x, counts.x, 1
    assert_in_delta timestamps.rect.y + timestamps.rect.height, counts.y + counts.height, 1
    shorter_strip = shorter_card.find(".community-curation-card-posters")
    last_poster = shorter_strip.all(".film-poster", count: 2).last.rect
    assert_in_delta full_strip.width, shorter_strip.rect.width, 1
    assert_in_delta shorter_strip.rect.x + shorter_strip.rect.width, last_poster.x + last_poster.width, 1

    original_size = page.current_window.size
    page.current_window.resize_to(430, 900)
    within card do
      assert_selector ".community-curation-card-posters .film-poster", count: 2
      first(".community-curation-card-posters .film-poster").click
    end
    assert_current_path community_curation_path(curation)
  ensure
    page.current_window.resize_to(*original_size) if original_size.present?
  end

  private

  def poster_action_dimensions
    [ find(".film-poster"), first(".library-card-actions .ui-action-button"), first(".library-card-actions .ui-action-button > svg") ].map do |element|
      bounds = element.rect
      [ bounds.width, bounds.height ]
    end
  end
end
