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
    action_row = find(".ui-page-body.ui-card .community-board-actions")
    create_action = action_row.find_link(I18n.t("community.curations.create"), class: "bg-primary")
    assert_in_delta action_row.rect.x + action_row.rect.width, create_action.rect.x + create_action.rect.width, 1
    create_action.click
    assert_curation_form_width find("main.community-curation-form")
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
      order_note = find("p")
      ordering_style = order_note.style(*type_properties)
      expand = find_button(I18n.t("community.curations.expand_all"))
      collapse = find_button(I18n.t("community.curations.collapse_all"), disabled: true)
      assert_equal ordering_style, expand.style(*type_properties)
      assert_equal ordering_style, collapse.style(*type_properties)
      assert_operator collapse.rect.x + collapse.rect.width, :<, order_note.rect.x
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
      assert_link I18n.t("community.curations.reply")
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

  test "the endorsement dialog preloads references and saves multiple films with comments" do
    password = "a long test password"
    author = Identity::UserRegistered.create!(email_address: "curation-response-browser@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true,
      community_username: "Respondent", community_avatar_preset: "moth",
      community_code_of_conduct_version: Community::CodeOfConduct.current.version,
      community_code_of_conduct_accepted_at: Time.current)
    reference, orchard, valley = [ "The Original Reference", "The Hidden Orchard", "The Quiet Valley" ].map do |title|
      film = Registry::Film.create!(title:, tmdb_metadata: { details: { genres: [ { name: "Horror" } ] } })
      Library::LibraryFilm.new(user: author, film:).add_to_watched!
      film
    end
    curation = Community::PublishCuration.call(author_id: author.id, title: "Folk horror in isolated places",
      prompt: "Films where the setting shapes the story.", reference_film_ids: [ reference.id ], reference_comments: {})

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: author.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    visit community_curation_path(curation)
    within "section[aria-labelledby=curation-nominated-films]" do
      find_link(I18n.t("community.curation_endorsements.edit_endorsements"), class: "bg-primary").click
    end
    assert_current_path community_curation_path(curation)
    search = I18n.t("community.curations.search_watched")
    dialog = find("dialog[open]")
    assert_in_delta 640, dialog.rect.width, 1
    within dialog do
      assert_field I18n.t("community.curations.comment_for_film", title: reference.title), with: ""
      fill_in search, with: reference.title
      assert_text I18n.t("community.curations.no_matches")
      assert_no_button I18n.t("community.curations.add_film", title: reference.title)
      { orchard => "The orchard isolates the family.", valley => "The valley keeps outsiders away." }.each do |film, body|
        fill_in search, with: film.title
        click_button I18n.t("community.curations.add_film", title: film.title)
        assert_field search, with: ""
        assert_no_selector ".community-reference-films"
        fill_in I18n.t("community.curations.comment_for_film", title: film.title), with: body
      end
      assert_comment_action_group(cancel: I18n.t("community.curations.cancel"), submit: I18n.t("community.curation_endorsements.save"))
      click_button I18n.t("community.curation_endorsements.save")
    end
    assert_no_selector "dialog[open]"
    assert_current_path community_curation_path(curation)
    assert_text I18n.t("community.curation_endorsements.saved")
    within "#nomination-#{orchard.id}" do
      find("summary", text: I18n.t("community.curations.comments", count: 1)).click
      assert_text "The orchard isolates the family."
      assert_no_text "The valley keeps outsiders away."
    end
    within "#nomination-#{valley.id}" do
      find("summary", text: I18n.t("community.curations.comments", count: 1)).click
      assert_text "The valley keeps outsiders away."
    end
  end

  test "the author edits a curation and must confirm its deletion" do
    password = "a long test password"
    author = Identity::UserRegistered.create!(email_address: "curation-edit-browser@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true,
      community_username: "CurationAuthor", community_avatar_preset: "moth",
      community_code_of_conduct_version: Community::CodeOfConduct.current.version,
      community_code_of_conduct_accepted_at: Time.current)
    curation = Community::PublishCuration.call(author_id: author.id, title: "Folk horror",
      prompt: "Folklore in film.", reference_film_ids: [], reference_comments: {})

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: author.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    visit community_curation_path(curation)
    delete_label = I18n.t("community.curation_deletion.delete_post")
    within ".community-curation-author-actions" do
      edit = find_link(I18n.t("community.curation_editing.edit_post"))
      delete = find_button(delete_label)
      assert_in_delta 132, edit.rect.width, 1
      assert_in_delta edit.rect.width, delete.rect.width, 1
      assert_in_delta 8, delete.rect.x - (edit.rect.x + edit.rect.width), 1
      edit.click
    end
    assert_current_path edit_community_curation_path(curation)
    card = find("main.community-curation-form")
    assert_curation_form_width card
    back_link = find_link(I18n.t("community.curations.back_to_curation"), href: community_curation_path(curation))
    assert_in_delta card.rect.x, back_link.rect.x, 1
    assert_in_delta 8, card.rect.y - (back_link.rect.y + back_link.rect.height), 1
    assert_field I18n.t("community.curations.title"), with: curation.title
    assert_field I18n.t("community.curations.description"), with: curation.prompt
    fill_in I18n.t("community.curations.title"), with: "Woodland folk horror"
    fill_in I18n.t("community.curations.description"), with: "Folklore in remote woodland."
    click_button I18n.t("community.curation_editing.save")
    assert_current_path community_curation_path(curation)
    assert_selector "h1", text: "Woodland folk horror"
    assert_text "Folklore in remote woodland."

    click_button delete_label
    within "dialog[open]" do
      description = find("p", text: I18n.t("community.curation_deletion.confirm_description")).rect
      cancel = find_button(I18n.t("community.curations.cancel"))
      confirm = find_button(delete_label)
      assert_in_delta 132, cancel.rect.width, 1
      assert_in_delta cancel.rect.width, confirm.rect.width, 1
      assert_in_delta cancel.rect.height, confirm.rect.height, 1
      assert_in_delta 8, confirm.rect.x - (cancel.rect.x + cancel.rect.width), 1
      assert_in_delta 28, cancel.rect.y - (description.y + description.height), 1
      cancel.click
    end
    assert_no_selector "dialog[open]"
    assert_current_path community_curation_path(curation)
    assert Community::Post.exists?(curation.id)

    click_button delete_label
    within("dialog[open]") { click_button delete_label }
    assert_current_path community_path
    assert_text I18n.t("community.curation_deletion.deleted")
    assert_no_text "Woodland folk horror"
    assert_not Community::Post.exists?(curation.id)
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
    search = find_field(I18n.t("community.search.label"))
    assert_selector "main:not(.ui-card) > .ui-page-heading form.community-board-search"
    fill_in I18n.t("community.search.label"), with: shorter.title
    assert_current_path community_path(q: shorter.title)
    assert_selector ".community-curation-card", count: 1, text: shorter.title
    assert_no_selector ".community-curation-card", text: curation.title
    fill_in I18n.t("community.search.label"), with: films.last.title
    assert_current_path community_path(q: films.last.title)
    assert_selector ".community-curation-card", count: 1, text: curation.title
    assert_no_selector ".community-curation-card", text: shorter.title
    click_link I18n.t("ui.search.clear")
    assert_current_path community_path
    assert_equal "", search.value
    assert_selector ".community-curation-card", count: 2
    create_action = find_link(I18n.t("community.curations.create")).rect
    posts = find(".community-curation-list").rect
    assert_in_delta 16, posts.y - (create_action.y + create_action.height), 1
    card = find(".community-curation-card", text: curation.title)
    shorter_card = find(".community-curation-card", text: shorter.title)
    assert_in_delta 12, card.rect.y - (shorter_card.rect.y + shorter_card.rect.height), 1
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
    assert_in_delta 12, card.rect.y - (shorter_card.rect.y + shorter_card.rect.height), 1
    action_row = find(".ui-page-body.ui-card .community-board-actions")
    create_action = action_row.find_link(I18n.t("community.curations.create"), class: "bg-primary").rect
    assert_in_delta action_row.rect.x + action_row.rect.width, create_action.x + create_action.width, 1
    within card do
      assert_selector ".community-curation-card-posters .film-poster", count: 2
      first(".community-curation-card-posters .film-poster").click
    end
    assert_current_path community_curation_path(curation)
  ensure
    page.current_window.resize_to(*original_size) if original_size.present?
  end

  test "members can post and independently reveal branches without endorsing the film" do
    password = "a long test password"
    author = Identity::UserRegistered.create!(email_address: "discussion-author@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true,
      community_username: "DiscussionAuthor", community_avatar_preset: "moth",
      community_code_of_conduct_version: Community::CodeOfConduct.current.version,
      community_code_of_conduct_accepted_at: Time.current)
    reader = Identity::UserRegistered.create!(email_address: "discussion-reader@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true,
      community_username: "DiscussionReader", community_avatar_preset: "moth",
      community_code_of_conduct_version: Community::CodeOfConduct.current.version,
      community_code_of_conduct_accepted_at: Time.current)
    first, second = [ "The Empty Field", "Folk Tales" ].map do |title|
      film = Registry::Film.create!(title:, tmdb_metadata: { details: { genres: [ { name: "Horror" } ] } })
      Library::LibraryFilm.new(user: author, film:).add_to_watched!
      film
    end
    curation = Community::PublishCuration.call(author_id: author.id, title: "Unsettling landscapes", prompt: "A strong sense of place.",
      reference_film_ids: [ first.id, second.id ], reference_comments: { first.id => "The landscape shapes the story.", second.id => "Woodland folklore." })
    root = curation.film_endorsements.find_by!(film: first).comments.sole

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: reader.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    path = community_curation_path(curation)
    visit path
    assert_no_text "The landscape shapes the story."
    find("#nomination-#{second.id} details.community-film-comments > summary").click
    within "#nomination-#{first.id}" do
      find("details.community-film-comments > summary").click
      click_link I18n.t("community.curations.reply")
    end
    assert_current_path path
    editor_width = nil
    within "#comment-thread-#{root.id}" do
      editor = find_field(I18n.t("community.curation_replies.body"))
      assert_selector "textarea:focus"
      assert_selector "#comment-#{root.id} + .community-comment-editor-branch .community-comment"
      assert_comment_gap find("#comment-#{root.id}"), find(".community-comment-editor-branch .community-comment")
      editor_width = editor.rect.width
      initial_height = editor.rect.height
      assert_operator initial_height, :<, 60
      editor.set("A first line.\nA second line.\nA third line.")
      assert_operator editor.rect.height, :>, initial_height
      editor.execute_script("this.removeAttribute('maxlength')")
      oversized_reply = "a" * (Community::CommentContent::REPLY_LIMIT + 1)
      editor.set(oversized_reply)
      click_button I18n.t("community.curation_replies.publish")
      assert_selector ".ui-errors li"
      assert_field I18n.t("community.curation_replies.body"), with: oversized_reply
      click_link I18n.t("community.curations.cancel")
      assert_no_field I18n.t("community.curation_replies.body")
      assert_selector "a:focus", text: I18n.t("community.curations.reply")
      click_link I18n.t("community.curations.reply")
      fill_in I18n.t("community.curation_replies.body"), with: "The sound design also helps."
      click_button I18n.t("community.curation_replies.publish")
    end
    assert_selector ".community-comment", text: "The sound design also helps."
    assert_current_path path
    reply = curation.comments.find_by!(parent: root)
    assert_selector "#replies-#{root.id}[open] > .community-comment-thread > #comment-#{reply.id}", text: "The sound design also helps."
    assert_in_delta find("#comment-#{reply.id} .community-curation-prompt").rect.width, editor_width, 1
    assert_text "Woodland folklore."
    assert_selector "#film-comment-count-#{first.id}", text: I18n.t("community.curations.comments", count: 2)
    assert_no_field I18n.t("community.curation_replies.body")
    within("#comment-#{root.id}") { click_link I18n.t("community.curations.reply") }
    assert_comment_gap find("#comment-composer-#{root.id} .community-comment"), find("#comment-#{reply.id}"),
      reply_count: find("#reply-count-#{root.id}")
    within "#comment-composer-#{root.id}" do
      fill_in I18n.t("community.curation_replies.body"), with: "The setting feels remote."
      click_button I18n.t("community.curation_replies.publish")
    end
    assert_selector "#replies-#{root.id}[open] > .community-comment-thread > .community-comment", text: "The setting feels remote."
    within "#comment-#{reply.id}" do
      click_link I18n.t("community.curations.reply")
    end
    fill_in I18n.t("community.curation_replies.body"), with: "Especially the quiet scenes."
    click_button I18n.t("community.curation_replies.publish")
    assert_selector "#replies-#{reply.id}[open] > .community-comment-thread > .community-comment", text: "Especially the quiet scenes."
    assert_equal root.id, curation.comments.find_by!(parent: reply).root_id
    within "#nomination-#{first.id}" do
      border_widths = %w[border-top-width border-right-width border-bottom-width border-left-width]
      all(".community-comment", count: 4).each do |comment|
        assert_equal [ "1px", "1px", "1px", "1px" ], comment.style(*border_widths).values
      end
      [ root, reply ].each do |parent|
        comment = find("#comment-#{parent.id}").rect
        branch = find("#replies-#{parent.id}")
        assert_in_delta comment.y + comment.height, branch.rect.y, 1
        threads = branch.all(":scope > .community-comment-thread")
        summary = branch.find(":scope > summary")
        assert_equal "4px", summary.style("padding-bottom").fetch("padding-bottom")
        assert_in_delta summary.rect.y + summary.rect.height, threads.first.rect.y, 1
        assert_comment_gap find("#comment-#{parent.id}"), threads.first.find(":scope > .community-comment"), reply_count: summary
        threads.each do |thread|
          start_x, end_x, elbow_y, radius, continuing = thread.evaluate_script(<<~JS)
            (() => {
              const style = getComputedStyle(this, "::before")
              const start = this.getBoundingClientRect().left + parseFloat(style.left)
              return [start, start + parseFloat(style.width), parseFloat(style.top) + parseFloat(style.height),
                style.borderEndStartRadius, getComputedStyle(this, "::after").content !== "none"]
            })()
          JS
          assert_in_delta branch.rect.x, start_x, 1
          assert_in_delta thread.rect.x, end_x, 1
          assert_in_delta 30, elbow_y, 1
          last_reply = thread == threads.last
          assert_equal "8px", radius
          assert_equal !last_reply, continuing
        end
      end
      assert_comment_gap find(".community-comment", text: "Especially the quiet scenes."),
        find(".community-comment", text: "The setting feels remote.")
    end
    assert_text "Woodland folklore."
    assert_current_path path

    nested = curation.comments.find_by!(parent: reply)
    deeper = Community::PublishCurationReply.call(curation_id: curation.id, comment_id: nested.id, member_id: reader.id,
      body: "The last shot has that mood too.").fetch(:reply).comment
    at_indent_limit = Community::PublishCurationReply.call(curation_id: curation.id, comment_id: deeper.id, member_id: reader.id,
      body: "The framing helps.").fetch(:reply).comment
    last_reply = Community::PublishCurationReply.call(curation_id: curation.id, comment_id: root.id, member_id: reader.id,
      body: "The empty roads add to the atmosphere.").fetch(:reply).comment

    visit path
    find("#nomination-#{first.id} details.community-film-comments > summary").click
    find("#nomination-#{second.id} details.community-film-comments > summary").click
    assert_text "The landscape shapes the story."
    assert_text "Woodland folklore."
    assert_no_text "The sound design also helps."
    click_button I18n.t("community.curations.expand_all")
    assert_text "The sound design also helps."
    assert_text "Especially the quiet scenes."
    deepest_thread = find("#comment-thread-#{at_indent_limit.id}")
    assert_in_delta find("#comment-thread-#{deeper.id}").rect.x, deepest_thread.rect.x, 1
    assert_equal "8px", deepest_thread.evaluate_script('getComputedStyle(this, "::before").borderEndStartRadius')
    next_reply = find(".community-comment", text: "The setting feels remote.")
    assert_comment_gap find("#comment-#{at_indent_limit.id}"), next_reply
    assert_comment_gap next_reply, find("#comment-#{last_reply.id}")
    assert_button I18n.t("community.curations.expand_all"), disabled: true
    reply_count = find("#reply-count-#{reply.id}")
    reply_count.click
    assert_no_text "Especially the quiet scenes."
    assert_equal "4px", reply_count.style("padding-bottom").fetch("padding-bottom")
    assert_comment_gap(find("#comment-#{reply.id}"), next_reply, reply_count:)
    assert_button I18n.t("community.curations.expand_all"), disabled: false
    reply_count.click
    assert_text "Especially the quiet scenes."
    click_button I18n.t("community.curations.collapse_all")
    assert_no_selector "details.community-film-comments[open], details.community-comment-replies[open]", visible: :all
    assert_button I18n.t("community.curations.collapse_all"), disabled: true
    find("#nomination-#{first.id} details.community-film-comments > summary").click
    assert_text "The landscape shapes the story."
    assert_no_text "The sound design also helps."
  end

  test "authors edit inline and confirm deleting comments while replies survive" do
    password = "a long test password"
    author, reader = %w[Editor Responder].map do |username|
      Identity::UserRegistered.create!(email_address: "#{username.downcase}@example.test", password:,
        password_confirmation: password, email_confirmed_at: Time.current, superuser: true,
        community_username: username, community_avatar_preset: "moth",
        community_code_of_conduct_version: Community::CodeOfConduct.current.version,
        community_code_of_conduct_accepted_at: Time.current)
    end
    film = Registry::Film.create!(title: "The Empty Field", tmdb_metadata: { details: { genres: [ { name: "Horror" } ] } })
    Library::LibraryFilm.new(user: author, film:).add_to_watched!
    curation = Community::PublishCuration.call(author_id: author.id, title: "Unsettling landscapes", prompt: "A strong sense of place.",
      reference_film_ids: [ film.id ], reference_comments: { film.id => "The landscape shapes the story." })
    root = curation.comments.sole
    leaf = Community::PublishCurationReply.call(curation_id: curation.id, comment_id: root.id, member_id: author.id,
      body: "My follow-up.").fetch(:reply).comment
    reply = Community::PublishCurationReply.call(curation_id: curation.id, comment_id: root.id, member_id: reader.id,
      body: "The sound design also helps.").fetch(:reply).comment

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: author.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    path = community_curation_path(curation)
    visit path
    click_button I18n.t("community.curations.expand_all")
    edit_label = I18n.t("community.comment_editing.edit")
    editor_label = I18n.t("community.comment_editing.body")
    save_label = I18n.t("community.comment_editing.save")
    delete_label = I18n.t("community.comment_deletion.delete")
    cancel_label = I18n.t("community.curations.cancel")

    click_button I18n.t("ui.dark_mode")
    assert_selector 'html[data-theme="light"]'
    within "#comment-#{root.id}" do
      assert_button(delete_label) { |button| button.style("color").fetch("color") == "rgba(143, 16, 27, 1)" }
    end
    click_button I18n.t("ui.dark_mode")
    assert_selector "html:not([data-theme])"

    source = find("#comment-#{leaf.id}")
    within(source) { click_link I18n.t("community.curations.reply") }
    reply_gap = within("#comment-composer-#{leaf.id}") do
      input = find_field(I18n.t("community.curation_replies.body")).rect
      submit = find_button(I18n.t("community.curation_replies.publish")).rect
      click_link cancel_label
      submit.y - (input.y + input.height)
    end

    text_bounds = source.find("span.community-curation-prompt").rect
    within source do
      assert_button(delete_label) { |button| button.style("color").fetch("color") == "rgba(195, 38, 48, 1)" }
      delete_action = find_button(delete_label)
      style = delete_action.style("background-color", "border-top-width", "color", "font-weight")
      assert_equal({ "background-color" => "rgba(0, 0, 0, 0)", "border-top-width" => "0px",
                     "color" => "rgba(195, 38, 48, 1)", "font-weight" => "700" }, style)
      click_link edit_label
    end
    editor_frame = source.find(".community-comment-edit-frame")
    editor_bounds = editor_frame.find_field(editor_label).rect
    assert_in_delta text_bounds.x, editor_bounds.x, 1
    assert_in_delta text_bounds.y, editor_bounds.y, 1
    assert_in_delta text_bounds.width, editor_bounds.width, 1
    save_y = editor_frame.find_button(save_label).rect.y
    assert_in_delta reply_gap, save_y - (editor_bounds.y + editor_bounds.height), 1
    within(editor_frame) { assert_comment_action_group(cancel: cancel_label, submit: save_label) }
    assert_no_selector "#comment-#{leaf.id} + .community-comment-editor-branch:not(:empty)"
    assert_no_selector "#comment-#{leaf.id} span.community-curation-prompt"
    within(editor_frame) { click_link cancel_label }
    within source do
      assert_selector "a:focus", text: edit_label
      assert_text "My follow-up."
      click_link edit_label
    end
    within "#edit-comment-composer-#{leaf.id}" do
      assert_field editor_label, with: "My follow-up."
      fill_in editor_label, with: " "
      click_button save_label
      assert_selector ".ui-errors li"
      assert_field editor_label
      fill_in editor_label, with: "My edited follow-up."
      click_button save_label
    end
    assert_selector "#comment-#{leaf.id} span.community-curation-prompt", text: "My edited follow-up."
    assert_text "The sound design also helps."
    assert_current_path path

    within("#comment-#{root.id}") { click_button delete_label }
    within("dialog[open]") { click_button cancel_label }
    assert_selector "#comment-#{root.id} span.community-curation-prompt", text: "The landscape shapes the story."
    within("#comment-#{root.id}") { click_button delete_label }
    within("dialog[open]") { click_button delete_label }
    within "#comment-#{root.id}" do
      assert_text I18n.t("community.curation_replies.removed")
      assert_no_link I18n.t("community.curations.reply")
    end
    assert_selector "#replies-#{root.id}[open] #comment-#{reply.id}", text: "The sound design also helps."
    assert_current_path path

    within("#comment-#{leaf.id}") { click_button delete_label }
    within("dialog[open]") { click_button delete_label }
    assert_no_selector "#comment-#{leaf.id}", visible: :all
    assert_selector "#film-comment-count-#{film.id}", text: I18n.t("community.curations.comments", count: 1)
    within("#comment-#{reply.id}") { assert_link I18n.t("community.curations.reply") }
  end

  test "the endorsement dialog warns about withdrawals, keeps failed drafts, and preserves replies" do
    password = "a long test password"
    author = Identity::UserRegistered.create!(email_address: "opening-comment-author@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true,
      community_username: "OpeningAuthor", community_avatar_preset: "moth",
      community_code_of_conduct_version: Community::CodeOfConduct.current.version,
      community_code_of_conduct_accepted_at: Time.current)
    film = Registry::Film.create!(title: "The Quiet Field", tmdb_metadata: { details: { genres: [ { name: "Horror" } ] } })
    Library::LibraryFilm.new(user: author, film:).add_to_watched!
    curation = Community::PublishCuration.call(author_id: author.id, title: "Rural horror", prompt: "Films with a strong sense of place.",
      reference_film_ids: [ film.id ], reference_comments: { film.id => "The landscape makes the whole film feel isolated." })
    root = curation.comments.sole
    reply = Community::PublishCurationReply.call(curation_id: curation.id, comment_id: root.id, member_id: author.id,
      body: "The fog helps too.").fetch(:reply).comment

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: author.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    path = community_curation_path(curation)
    visit path
    edit = I18n.t("community.curation_endorsements.edit_endorsements")
    save = I18n.t("community.curation_endorsements.save")
    body = I18n.t("community.curations.comment_for_film", title: film.title)
    warning = I18n.t("community.curation_endorsements.withdrawal")
    original_body = root.content.body

    click_link edit
    within "dialog[open]" do
      assert_field body, with: original_body
      fill_in body, with: " "
      click_button save
    end
    within "dialog[open]" do
      assert_selector ".ui-errors li", text: /Use Delete on the published comment/
      assert_field body, with: " "
      click_button I18n.t("community.curations.remove_film", title: film.title)
      assert_text warning
      click_link I18n.t("community.curations.cancel")
    end
    assert_no_selector "dialog[open]"
    click_link edit
    within "dialog[open]" do
      assert_field body, with: original_body
      assert_no_text warning
      click_button I18n.t("community.curations.remove_film", title: film.title)
      assert_text warning
      click_button save
    end
    assert_no_selector "dialog[open]"
    assert_current_path path
    within "#nomination-#{film.id}" do
      assert_text I18n.t("community.curations.endorsements", count: 0)
      find("#film-comment-count-#{film.id}").click
      assert_no_text original_body
      assert_selector "#comment-#{root.id}", text: I18n.t("community.curation_replies.removed")
      find("#reply-count-#{root.id}").click
      within "#comment-#{reply.id}" do
        assert_text "The fog helps too."
        assert_link I18n.t("community.curations.reply")
      end
    end

    click_link I18n.t("community.curation_endorsements.endorse_films")
    within "dialog[open]" do
      assert_no_field body
      fill_in I18n.t("community.curations.search_watched"), with: film.title
      click_button I18n.t("community.curations.add_film", title: film.title)
      fill_in body, with: "The setting makes the film feel intimate."
      click_button save
    end
    assert_no_selector "dialog[open]"
    assert_link edit
    within "#nomination-#{film.id}" do
      assert_text I18n.t("community.curations.endorsements", count: 1)
      find("#film-comment-count-#{film.id}").click
      assert_selector "#comment-#{root.id}", text: I18n.t("community.curation_replies.removed")
      assert_selector ".community-comment", text: "The setting makes the film feel intimate."
    end
  end

  private

  def assert_curation_form_width(card)
    original_size = page.current_window.size
    assert_in_delta 640, card.rect.width, 1
    page.current_window.resize_to(690, 900)
    assert_in_delta 640, card.rect.width, 1
    page.current_window.resize_to(520, 900)
    available_width = page.evaluate_script("document.body.getBoundingClientRect().width")
    assert_in_delta available_width - 32, card.rect.width, 1
    assert_in_delta 16, card.rect.x, 1
  ensure
    page.current_window.resize_to(*original_size) if original_size.present?
  end

  def assert_comment_gap(previous_comment, next_comment, reply_count: nil)
    previous_bounds = previous_comment.rect
    expected_gap = reply_count.present? ? reply_count.rect.height : 16
    assert_in_delta expected_gap, next_comment.rect.y - (previous_bounds.y + previous_bounds.height), 1
  end

  def assert_comment_action_group(cancel:, submit:)
    within ".ui-actions-fixed" do
      cancel_link = find_link(cancel)
      cancel_rect = cancel_link.rect
      submit_rect = find_button(submit).rect
      assert_equal "rgba(0, 0, 0, 0)", cancel_link.style("background-color").fetch("background-color")
      assert_equal [ 132, 132 ], [ cancel_rect.width, submit_rect.width ]
      assert_equal [ 44, 44 ], [ cancel_rect.height, submit_rect.height ]
      assert_in_delta 8, submit_rect.x - (cancel_rect.x + cancel_rect.width), 1
    end
  end

  def poster_action_dimensions
    [ find(".film-poster"), first(".library-card-actions .ui-action-button"), first(".library-card-actions .ui-action-button > svg") ].map do |element|
      bounds = element.rect
      [ bounds.width, bounds.height ]
    end
  end
end
