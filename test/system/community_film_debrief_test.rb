require "application_system_test_case"

class CommunityFilmDebriefBrowserTest < ApplicationSystemTestCase
  test "search creates a debrief directly and the unfiltered board links to it" do
    password = "a long test password"
    member = create_community_account(email_address: "debrief-browser@example.test", password:, password_confirmation: password,
      email_confirmed_at: Time.current, community_username: "debrief_browser", community_avatar_preset: "moth",
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

    assert_selector "h1", text: film.title
    debrief = Community::PostFilmDebrief.find_by!(film:)
    assert_current_path community_post_path(debrief)
    find(".community-post-tag", text: I18n.t("community.film_debriefs.badge")).hover
    assert_selector "[role=tooltip]", text: I18n.t("community.film_debriefs.badge_tooltip")

    click_link I18n.t("community.curations.back")
    assert_current_path community_path
    assert_link film.title, href: community_post_path(debrief)
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
    assert_link film.title, href: community_post_path(debrief)
    click_link I18n.t("ui.search.clear")
    assert_current_path community_path
    click_link film.title
    assert_current_path community_post_path(debrief)
  end

  test "a debrief supports inline comments, replies, editing, and confirmed deletion" do
    password = "a long test password"
    member = create_community_account(email_address: "debrief-discussion-browser@example.test", password:, password_confirmation: password,
      email_confirmed_at: Time.current, community_username: "debrief_discussion", community_avatar_preset: "moth",
      community_code_of_conduct_version: Community::CodeOfConduct.current.version, community_code_of_conduct_accepted_at: Time.current)
    film = Registry::Film.create!(title: "A Long Night in an Empty Hospital", release_date: Date.new(1987, 4, 1), tmdb_metadata: { details: {} })
    Library::LibraryFilm.new(user: member, film:).add_to_watched!
    debrief = Community::FilmDebriefs::OpenFilmDebrief.call(community_user: member.community_user, film_id: film.id)

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: member.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    visit community_post_path(debrief)
    assert_selector "h1 .film-year", text: "(1987)"
    title = find("h1").rect
    poster = find(".community-debrief-poster .film-poster").rect
    assert_operator poster.x + poster.width, :<=, title.x
    assert_in_delta title.y, poster.y, 1
    within ".community-debrief-intro" do
      badge = find(".community-post-tag", text: I18n.t("community.film_debriefs.badge")).rect
      author = find(".community-film-debrief-author", text: I18n.t("ui.wordmark")).rect
      assert_operator title.y + title.height, :<=, badge.y
      assert_operator badge.y + badge.height, :<=, author.y
      assert_operator author.y + author.height, :<=, find("p").rect.y
    end
    assert_operator poster.y + poster.height, :<=, find(".community-debrief-discussion").rect.y

    composer_id = "#film-debrief-#{debrief.id}-composer"
    publish_label = I18n.t("community.film_debriefs.publish_comment")
    within composer_id do
      assert_selector ".community-member-avatar"
      assert_operator find_button(publish_label, disabled: true).rect.width, :<, find("textarea").rect.width
    end

    browser = page.driver.browser
    browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 900, deviceScaleFactor: 1, mobile: false)
    mobile_poster = find(".community-debrief-poster .film-poster").rect
    introduction = find(".community-debrief-intro p").rect
    assert_operator find(".community-film-debrief-author").rect.x, :>, mobile_poster.x
    assert_operator introduction.y, :>=, mobile_poster.y + mobile_poster.height
    assert_operator introduction.x, :<, find("h1").rect.x
    assert_operator find(".community-debrief-discussion").rect.y, :>=, introduction.y + introduction.height
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

    within composer_id do
      textarea = find("textarea[maxlength='4000']")
      button = find_button(publish_label, disabled: true)
      editor = find(".community-comment").rect
      assert_operator button.rect.y, :>, editor.y + editor.height
      assert_operator button.rect.width, :>=, editor.width * 0.99
      assert_operator button.rect.x, :<, textarea.rect.x
      assert_no_selector ".community-member-avatar"
      assert_equal "nowrap", button.style("white-space").fetch("white-space")
      assert button.evaluate_script("this.scrollWidth <= this.clientWidth")
      fill_in I18n.t("community.comment_editing.body"), with: "   "
      assert_button publish_label, disabled: true
      fill_in I18n.t("community.comment_editing.body"), with: "How did everyone interpret the ending?"
      assert_button publish_label, disabled: false
      click_button publish_label
    end
    assert_selector "article.community-comment", text: "How did everyone interpret the ending?"
    root = debrief.comments.sole
    discussion = find(".community-debrief-discussion")
    comment_gap = discussion.evaluate_script("parseFloat(getComputedStyle(this).getPropertyValue('--comment-gap'))")
    composer = find(composer_id).rect
    assert_in_delta comment_gap, find("#comment-#{root.id}").rect.y - (composer.y + composer.height), 1
    within composer_id do
      fill_in I18n.t("community.comment_editing.body"), with: "The score stood out too."
      click_button publish_label
    end
    next_root = find("article.community-comment", text: "The score stood out too.").rect
    previous_root = find("#comment-#{root.id}").rect
    assert_in_delta comment_gap, next_root.y - (previous_root.y + previous_root.height), 1
    within "#comment-#{root.id}" do
      click_link I18n.t("community.curations.reply")
    end

    within "#comment-composer-#{root.id}" do
      assert_selector "textarea[maxlength='4000']"
      fill_in I18n.t("community.curation_replies.body"), with: "The final shot changes the meaning."
      click_button I18n.t("community.curation_replies.publish")
    end
    assert_selector "#replies-#{root.id}[open] article", text: "The final shot changes the meaning."
    reply = debrief.comments.find_by!(parent: root)
    within "#comment-#{reply.id}" do
      content_start = find(".community-member-avatar").rect.x
      click_link I18n.t("community.comment_editing.edit")
      assert_button I18n.t("community.comment_editing.save"), disabled: true
      assert_no_selector ".community-member-avatar"
      assert_in_delta content_start, find("textarea").rect.x, 1
      fill_in I18n.t("community.comment_editing.body"), with: "The final shot changes the meaning of the first scene."
      click_button I18n.t("community.comment_editing.save")
      assert_text "The final shot changes the meaning of the first scene."
      assert_selector ".community-comment-edited", text: I18n.t("community.comment_editing.edited")
      assert_selector ".community-member-avatar"
    end

    delete_label = I18n.t("community.comment_deletion.delete")
    within "#comment-#{root.id}" do
      click_button delete_label
      within "dialog[open]" do
        click_button I18n.t("community.curations.cancel")
      end
      assert_text "How did everyone interpret the ending?"
      click_button delete_label
      within "dialog[open]" do
        click_button delete_label
      end
    end
    assert_selector "#comment-#{root.id}", text: I18n.t("community.curation_replies.removed")
    assert_selector "#replies-#{root.id}[open] #comment-#{reply.id}"
    within "#comment-#{root.id}" do
      assert_no_link I18n.t("community.curations.reply")
      assert_no_text member.community_user&.community_username
    end
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
  ensure
    browser&.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
