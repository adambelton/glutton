require "application_system_test_case"

class CommunityFilmDebriefBrowserTest < ApplicationSystemTestCase
  test "search creates a debrief directly and the unfiltered board links to it" do
    password = "a long test password"
    member = Identity::UserRegistered.create!(email_address: "debrief-browser@example.test", password:, password_confirmation: password,
      email_confirmed_at: Time.current, superuser: true, community_username: "debrief_browser", community_avatar_preset: "moth",
      community_code_of_conduct_version: Community::CodeOfConduct.current.version, community_code_of_conduct_accepted_at: Time.current)
    film = Registry::Film.create!(title: "The Quiet House", tmdb_metadata: { details: {} })
    Library::LibraryFilm.new(user: member, film:).add_to_watched!

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: member.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    visit community_path

    create_label = I18n.t("community.film_debriefs.create")
    assert_no_button create_label
    fill_in I18n.t("community.search.label"), with: "Quiet"
    assert_current_path community_path(q: "Quiet")
    within ".community-film-debrief-card" do
      poster = find(".film-poster")
      title = find("h2", text: film.title)
      action = find_button(create_label)
      assert_operator poster.rect.x + poster.rect.width, :<=, title.rect.x
      assert_operator title.rect.y + title.rect.height, :<=, action.rect.y
      assert_no_selector ".community-post-tag"
      within "h2 + form.community-film-debrief-create" do
        click_button create_label
      end
    end

    assert_current_path community_film_debrief_path(film)
    assert_selector "h1", text: film.title
    find(".community-post-tag", text: I18n.t("community.film_debriefs.badge")).hover
    assert_selector "[role=tooltip]", text: I18n.t("community.film_debriefs.badge_tooltip")

    click_link I18n.t("community.curations.back")
    assert_current_path community_path
    assert_link film.title, href: community_film_debrief_path(film)
    assert_selector "a.community-film-debrief-card .community-post-card-artwork > .film-poster", count: 1
    assert_no_selector "a.community-film-debrief-card time"
    within "a.community-film-debrief-card" do
      assert_selector "h2 + .community-post-tag", text: I18n.t("community.film_debriefs.badge")
      assert_selector "footer > p", text: I18n.t("community.curations.comments", count: 0)
      assert_selector "footer .community-glutton-avatar + strong", text: I18n.t("ui.wordmark")
    end
    assert_no_button create_label
    fill_in I18n.t("community.search.label"), with: "Quiet"
    assert_current_path community_path(q: "Quiet")
    assert_link film.title, href: community_film_debrief_path(film)
    click_link I18n.t("ui.search.clear")
    assert_current_path community_path
    click_link film.title
    assert_current_path community_film_debrief_path(film)
  end
end
