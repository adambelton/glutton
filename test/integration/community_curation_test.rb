require "test_helper"

class CommunityCurationTest < ActionDispatch::IntegrationTest
  PASSWORD = "a long test password"

  setup do
    controllers = [ Community::CurationsController, Community::CurationResponsesController, Community::CurationRepliesController, Community::CurationCommentsController,
                    Community::BoardController, LibraryController ]
    @previous_forgery_protection = controllers.index_with(&:allow_forgery_protection)
    controllers.each { |controller| controller.allow_forgery_protection = true }
    @author = member("curation_author")
  end

  teardown do
    @previous_forgery_protection.each { |controller, enabled| controller.allow_forgery_protection = enabled }
  end

  test "publishes a tagged curation and displays one endorsement for every reference" do
    first = film("The Watchers")
    second = film("A Field at Night")
    non_horror = film("Comedy Show", genre: "Comedy")
    [ first, second, non_horror ].each { |reference| watch(@author, reference) }
    watch(member("other_viewer"), film("Another Member's Film"))
    sign_in(@author)

    get community_path
    assert_select "main:not(.ui-card) > .ui-page-body.ui-card .community-board-actions a.bg-primary[href=?]",
      new_community_curation_path, text: I18n.t("community.curations.create")
    assert_select "nav.community-board-pagination > span", text: I18n.t("community.pagination.page", number: 1)
    get new_community_curation_path
    assert_response :success
    assert_select ".ui-page-back-above + main.ui-card.ui-narrow"
    assert_select ".ui-page-back-above a[href=?]", community_path, text: I18n.t("community.curations.back")
    assert_select "#curation_title[aria-describedby=curation_title_hint]"
    assert_select "#curation_title_hint", text: I18n.t("community.curations.title_hint")
    assert_select "label[for=curation_prompt]", text: I18n.t("community.curations.description")
    assert_select "#curation_prompt[aria-describedby=curation_description_hint] + #curation_description_hint",
      text: I18n.t("community.curations.description_hint")
    assert_select "#curation_reference_search[placeholder=?]", I18n.t("community.curations.search_watched")
    assert_select ".community-reference-picker > legend > #curation_reference_hint",
      text: I18n.t("community.curations.reference_hint", count: 5)
    assert_select ".community-reference-picker > legend + #curation_reference_search[aria-describedby=curation_reference_hint]"
    assert_select ".community-reference-films[hidden] > li", count: 2
    assert_select ".community-reference-films > li[data-film-id=?]", first.id.to_s
    assert_select ".community-reference-films > li[data-film-id=?]", second.id.to_s
    assert_select "input[name*=tag], select[name*=tag]", count: 0

    assert_difference "Community::PostCommunityCuration.count", 1 do
      submit_curation(reference_film_ids: [ first.id, second.id ],
        reference_comments: { first.id.to_s => "The sense of dread builds slowly.", second.id.to_s => " " }, tag: "Film Debrief")
    end
    assert_response :see_other
    curation = Community::PostCommunityCuration.find_by!(title: "Slow-burn modern folk horror")
    assert_redirected_to community_curation_path(curation)
    assert_equal @author, curation.author
    assert_equal [ [ second.id, @author.id ], [ first.id, @author.id ] ].sort,
      curation.film_endorsements.pluck(:film_id, :user_id).sort
    comment = curation.film_endorsements.find_by!(film: first).comment
    assert_equal curation, comment.post
    assert_equal @author, comment.content.author
    assert_equal "The sense of dread builds slowly.", comment.content.body
    assert_nil curation.film_endorsements.find_by!(film: second).comment

    follow_redirect!
    assert_select "h1", curation.title
    assert_select ".ui-page-back-above + main.community-curation-page.ui-card"
    assert_select ".ui-page-back-above a[href=?]", community_path, text: I18n.t("community.curations.back")
    assert_select ".community-curation-prompt", "Stories that take their time."
    assert_select ".community-post-tag", text: I18n.t("community.curations.tag"), count: 1
    assert_select "h2.sr-only", I18n.t("community.curations.nominated_films")
    assert_select "ol.community-nominations > li" do |rows|
      assert_equal [ second.title, first.title ], rows.map { |row| row.at_css("h3").text }
    end
    assert_select "p", text: I18n.t("community.curations.endorsement_order")
    assert_select ".community-endorsement-badge", text: I18n.t("community.curations.endorsements", count: 1), count: 2
    assert_select "#nomination-#{first.id} details:not([open])" do
      assert_select "summary", text: I18n.t("community.curations.comments", count: 1)
      assert_select "article span.community-curation-prompt", text: "The sense of dread builds slowly."
      assert_select "article strong", text: @author.community_username
      assert_select "article a", text: I18n.t("community.curations.reply")
      assert_select "article button[disabled]", text: I18n.t("community.curations.report")
    end
    assert_select "#nomination-#{second.id}" do
      assert_select "p.community-comment-count", text: I18n.t("community.curations.comments", count: 0)
      assert_select "details", count: 0
    end

    sign_in(member("preview_reader", accepted: false, username: false, avatar: false))
    get community_path
    assert_select "a.community-curation-card[href=?]", community_curation_path(curation), count: 1 do |links|
      assert_select "h2[id=?]", links.first["aria-labelledby"], text: curation.title
      assert_select "p", text: curation.prompt, count: 0
      assert_select ".community-curation-card-heading + .community-curation-card-byline", text: I18n.t("community.curations.authored_by", username: @author.community_username)
      assert_select ".community-curation-card-heading .community-post-tag", text: I18n.t("community.curations.tag")
      assert_select ".community-curation-card-timestamps > span", text: /\ACreated / do
        assert_select "time[datetime=?]", curation.created_at.iso8601
      end
      assert_select ".community-curation-card-timestamps > span", text: /\AUpdated / do
        assert_select "time[datetime=?]", curation.updated_at.iso8601
      end
      assert_select "footer .community-curation-card-counts li", text: I18n.t("community.curations.films", count: 2)
      assert_select "footer .community-curation-card-counts li", text: I18n.t("community.curations.endorsements", count: 2)
      assert_select "footer .community-curation-card-counts li", text: I18n.t("community.curations.comments", count: 1)
      assert_select ".community-curation-card-posters .film-poster", count: 2
    end
    assert_select ".community-post-tag", text: I18n.t("community.curations.tag"), count: 1
    assert_select "a[href=?]", new_community_curation_path, count: 0
    get community_curation_path(curation)
    assert_response :success
  end

  test "publishes with no reference films" do
    sign_in(@author)
    get new_community_curation_path
    assert_difference "Community::PostCommunityCuration.count", 1 do
      assert_no_difference "Community::FilmEndorsement.count" do
        submit_curation
      end
    end
    follow_redirect!
    assert_select "p", I18n.t("community.curations.no_nominations")
  end

  test "films with more endorsements are listed first" do
    first = film("A Field at Night")
    second = film("The Watchers")
    curation = publish_with(first, second)
    endorser = member("another_endorser")
    watch(endorser, second)
    Community::FilmEndorsement.create!(post: curation, film: second, user: endorser)
    sign_in(@author)

    get community_curation_path(curation)
    assert_select "ol.community-nominations h3" do |headings|
      assert_equal [ second.title, first.title ], headings.map(&:text)
    end
    assert_select "#nomination-#{second.id} .community-nomination-rank", text: "1."
    assert_select "#nomination-#{first.id} .community-nomination-rank", text: "2."
    assert_select "#nomination-#{second.id} .community-endorsement-badge", text: I18n.t("community.curations.endorsements", count: 2)

    get community_path
    assert_select ".community-curation-card-posters .film-poster" do |posters|
      assert_equal [ second, first ].map { |film| I18n.t("registry.film_presentation.no_poster", title: film.title) },
        posters.map { |poster| poster["aria-label"] }
    end
    assert_select ".community-curation-card-counts li", text: I18n.t("community.curations.endorsements", count: 3)
  end

  test "a reader can save nominations to their own Library before Community setup" do
    first, second = film("A Field at Night"), film("The Watchers")
    curation = publish_with(first, second)
    activity_at = curation.updated_at
    viewer = member("library_reader", accepted: false, username: false, avatar: false)
    sign_in(viewer)

    get community_curation_path(curation)
    watchlist_path = watchlist_community_curation_path(curation)
    watched_path = watched_community_curation_path(curation)
    post watchlist_path, params: nomination_form(watchlist_path, film: first)
    assert_redirected_to community_curation_path(curation)
    assert Library::LibraryFilm.watchlist.exists?(user: viewer, film: first)

    follow_redirect!
    assert_select "#nomination-#{first.id} button[aria-label=?][aria-disabled=true][data-in-collection=true]", I18n.t("library.search.in_watchlist")
    post watched_path, params: nomination_form(watched_path, film: first)
    assert_redirected_to community_curation_path(curation)
    assert Library::LibraryFilm.watched.exists?(user: viewer, film: first)

    follow_redirect!
    assert_select "#nomination-#{first.id} .community-nomination-media" do
      assert_select "button[aria-label=?][aria-disabled=true][data-in-collection=true]", I18n.t("library.search.in_watched")
      assert_select "button[aria-label=?][aria-disabled=true]:not([data-in-collection])", I18n.t("community.curations.watchlist_unavailable_when_watched")
      assert_select "form", count: 0
    end
    post watched_path, params: nomination_form(watched_path, film: second)
    assert_redirected_to community_curation_path(curation)
    assert Library::LibraryFilm.watched.exists?(user: viewer, film: second)
    assert_equal 2, curation.film_endorsements.count
    assert_equal activity_at, curation.reload.updated_at
  end

  test "curation Library submissions reject unrelated films, stale actions and unauthorised viewers" do
    nominated = film("A Nomination")
    unrelated = film("Unrelated Film")
    curation = publish_with(nominated)
    viewer = member("library_reader")
    sign_in(viewer)
    path = watchlist_community_curation_path(curation)
    get community_curation_path(curation)
    selection = nomination_form(path, film: nominated)

    assert_no_difference "Library::LibraryFilm.count" do
      post path, params: selection.merge(film_id: unrelated.id)
    end
    assert_response :not_found

    Library::CollectionManagement::AddToWatchlist.call(user_id: viewer.id, film_id: nominated.id)
    assert_no_difference "Library::LibraryFilm.count" do
      post path, params: selection
    end
    assert_redirected_to community_curation_path(curation)
    assert_equal I18n.t("community.curations.library_action_unavailable"), flash[:alert]

    sign_in(member("outside_preview", superuser: false))
    get library_path
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
    assert_no_difference "Library::LibraryFilm.count" do
      post path, params: selection.merge(authenticity_token: token)
    end
    assert_response :forbidden
  end

  test "the board lists ten posts at a time with a stable order for equal update timestamps" do
    freeze_time do
      12.times do |index|
        Community::PublishCuration.call(author_id: @author.id, title: "Curation #{index + 1}",
          prompt: "Films for this theme.", reference_film_ids: [], reference_comments: {})
      end
    end
    sign_in(member("board_reader", accepted: false, username: false, avatar: false))

    get community_path
    assert_response :success
    assert_select ".community-curation-card h2", count: 10 do |titles|
      assert_equal 12.downto(3).map { |number| "Curation #{number}" }, titles.map(&:text)
    end
    assert_select "nav.community-board-pagination > span", text: I18n.t("community.pagination.page", number: 1)
    assert_select "nav a[rel=next][href=?]", community_path(page: 2)
    assert_select "nav a[rel=prev]", count: 0

    get community_path(page: 2)
    assert_response :success
    assert_select ".community-curation-card h2", count: 2 do |titles|
      assert_equal [ "Curation 2", "Curation 1" ], titles.map(&:text)
    end
    assert_select "nav.community-board-pagination > span", text: I18n.t("community.pagination.page", number: 2)
    assert_select "nav a[rel=prev][href=?]", community_path
    assert_select "nav a[rel=next]", count: 0

    get community_path(page: 3)
    assert_redirected_to community_path(page: 2)
    get community_path(page: "invalid")
    assert_redirected_to community_path
  end

  test "the board filters post text and carries the query through pagination" do
    matching_title = "Folk% horror in the woods"
    11.times do |index|
      Community::PublishCuration.call(author_id: @author.id, title: (index.zero? ? matching_title : "Curation #{index}"),
        prompt: (index.zero? ? "Selected by title." : "More Folk% Horror films."), reference_film_ids: [], reference_comments: {})
    end
    Community::PublishCuration.call(author_id: @author.id, title: "Folk tale horror", prompt: "Unrelated wording.",
      reference_film_ids: [], reference_comments: {})
    sign_in(@author)

    query = "folk% horror"
    get community_path(q: query)
    assert_response :success
    assert_select "#community-board-query[value=?]", query
    assert_select ".community-curation-card h2", count: 10
    assert_select ".community-curation-card h2", text: "Folk tale horror", count: 0
    assert_select "nav a[rel=next][href=?]", community_path(q: query, page: 2)

    get community_path(q: query, page: 2)
    assert_response :success
    assert_select ".community-curation-card h2", text: matching_title, count: 1
    assert_select "nav a[rel=prev][href=?]", community_path(q: query)

    get community_path(q: query, page: 3)
    assert_redirected_to community_path(q: query, page: 2)
  end

  test "board cards expose timestamps and sort by the latest update" do
    created_at = Time.zone.local(2026, 11, 20, 9, 15)
    updated_at = Time.zone.local(2026, 11, 23, 14, 30)
    earlier_post = Community::PostCommunityCuration.create!(author: @author, title: "Slow-burn horror", prompt: "Films for this theme.",
      created_at:, updated_at:)
    newer_post = Community::PostCommunityCuration.create!(author: @author, title: "Folk horror", prompt: "Films for this theme.",
      created_at: Time.zone.local(2026, 11, 21, 9, 15), updated_at: Time.zone.local(2026, 11, 22, 14, 30))
    sign_in(@author)

    get community_path
    assert_select ".community-curation-card h2" do |titles|
      assert_equal [ earlier_post.title, newer_post.title ], titles.map(&:text)
    end
    assert_select ".community-curation-list > li:first-child .community-curation-card-timestamps > span", text: /\ACreated / do
      assert_select "time[datetime=?]", created_at.iso8601, text: I18n.l(created_at, format: :community_curation_card)
    end
    assert_select ".community-curation-list > li:first-child .community-curation-card-timestamps > span:first-child", text: /\AUpdated / do
      assert_select "time[datetime=?]", updated_at.iso8601, text: I18n.l(updated_at, format: :community_curation_card)
    end
  end

  test "film title matches find a curation once even when the films are outside the reader's library" do
    first = film("Across the Distant Marsh")
    second = film("Beyond the Distant Marsh")
    matching_curation = publish_with(first, second)
    unrelated_curation = publish_with(film("Night in the Woods"))
    sign_in(member("film_search_reader", accepted: false))

    get community_path(q: "distant marsh")
    assert_response :success
    assert_select ".community-curation-card", count: 1
    assert_select ".community-curation-card[href=?]", community_curation_path(matching_curation)
    assert_select ".community-curation-card[href=?]", community_curation_path(unrelated_curation), count: 0

    get community_path(q: "something else")
    assert_select ".ui-empty", text: I18n.t("community.search.no_matches")
    assert_select "nav.community-board-pagination > span", text: I18n.t("community.pagination.page", number: 1)
  end

  test "rejects another member's watched film and an author's watchlist film without saving" do
    watched_elsewhere = film("Someone Else Watched This")
    on_watchlist = film("Still to See")
    valid = film("Watched by the Author")
    watch(member("someone_else"), watched_elsewhere)
    watch(@author, valid)
    Library::LibraryFilm.new(user: @author, film: on_watchlist).add_to_watchlist!
    sign_in(@author)

    [ watched_elsewhere, on_watchlist ].each do |ineligible|
      get new_community_curation_path
      assert_select ".community-reference-films > li", count: 1
      assert_select ".community-reference-films > li[data-film-id=?]", valid.id.to_s
      assert_no_difference [ "Community::Post.count", "Community::FilmEndorsement.count", "Community::Comment.count", "Community::CommentContent.count" ] do
        submit_curation(reference_film_ids: [ valid.id, ineligible.id ], reference_comments: { valid.id.to_s => "Keep my comment." })
      end
      assert_response :unprocessable_content
      assert_select "ul.ui-errors li", text: /must be eligible horror films/
      assert_select ".community-selected-films > li[data-film-id=?] textarea", valid.id.to_s, text: "Keep my comment."
      assert_select "#curation_title[value=?]", "Slow-burn modern folk horror"
    end
  end

  test "rechecks Watched when the author publishes from a stale form" do
    reference = film("Removed From Watched")
    entry = watch(@author, reference)
    sign_in(@author)
    get new_community_curation_path
    assert_select ".community-reference-films > li[data-film-id=?]", reference.id.to_s

    Library::CollectionManagement::RemoveFromWatched.call(user_id: @author.id, library_film_id: entry.id)
    assert_no_difference [ "Community::Post.count", "Community::FilmEndorsement.count" ] do
      submit_curation(reference_film_ids: [ reference.id ])
    end
    assert_response :unprocessable_content
  end

  test "validates the text limits and the number and distinctness of references" do
    sign_in(@author)
    get new_community_curation_path
    assert_no_difference "Community::Post.count" do
      submit_curation(title: "a" * 121, prompt: "b" * 2001, reference_film_ids: [ 1, 1, 2, 3, 4, 5 ])
    end
    assert_response :unprocessable_content
    assert_select "ul.ui-errors li", count: 4

    get new_community_curation_path
    assert_no_difference "Community::Post.count" do
      submit_curation(title: " ", prompt: " ")
    end
    assert_response :unprocessable_content
    assert_select "ul.ui-errors li", count: 2
  end

  test "requires a flat array of valid reference IDs" do
    sign_in(@author)
    get new_community_curation_path
    assert_no_difference "Community::Post.count" do
      submit_curation(reference_film_ids: "3")
    end
    assert_response :bad_request
  end

  test "rejects a comment for a reference that was not selected" do
    sign_in(@author)
    get new_community_curation_path
    assert_no_difference [ "Community::Post.count", "Community::Comment.count", "Community::CommentContent.count" ] do
      submit_curation(reference_comments: { "3" => "A comment without a reference." })
    end
    assert_response :bad_request
  end

  test "each missing onboarding prerequisite independently blocks publication" do
    [
      member("no_conduct", accepted: false),
      member("no_name", username: false),
      member("no_avatar", avatar: false)
    ].each do |viewer|
      sign_in(viewer)
      get community_path
      assert_response :success
      assert_select "a[href=?]", new_community_curation_path, count: 0
      assert_no_difference "Community::Post.count" do
        submit_curation
      end
      assert_response :forbidden
      get new_community_curation_path
      assert_response :forbidden
    end
  end

  test "members outside the preview cannot access or publish curations directly" do
    sign_in(@author)
    get new_community_curation_path
    submit_curation
    curation = Community::PostCommunityCuration.find_by!(author: @author)
    sign_in(member("locked_out", superuser: false))
    get library_path
    assert_no_difference "Community::Post.count" do
      submit_curation
    end
    assert_response :forbidden
    [ community_path, new_community_curation_path, community_curation_path(curation) ].each do |path|
      get path
      assert_response :forbidden
    end
  end

  test "account closure and deletion replay remove curations and initial endorsements" do
    [ @author, member("restored_author") ].each do |author|
      reference = film("A Reference for #{author.community_username}")
      watch(author, reference)
      sign_in(author)
      get new_community_curation_path
      submit_curation(reference_film_ids: [ reference.id ], reference_comments: { reference.id.to_s => "It fits the theme." })
      assert_response :see_other
    end
    live_post, restored_post = Community::PostCommunityCuration.order(:id).to_a
    live_endorsement = live_post.film_endorsements.sole
    restored_endorsement = restored_post.film_endorsements.sole
    live_comment = live_endorsement.comment
    restored_comment = restored_endorsement.comment
    live_content = live_comment.content
    restored_content = restored_comment.content
    client = Aws::S3::Client.new(region: "auto", stub_responses: true)
    log = Identity::AccountAdministration::DeletionLog.new(client:, bucket: "fixture", namespace: "recovery")
    Identity::AccountAdministration::ManageRegisteredAccount.new(user_id: @author.id).close_account(deletion_log: log)
    assert_not Community::Post.exists?(live_post.id)
    assert_not Community::FilmEndorsement.exists?(live_endorsement.id)
    assert_not Community::Comment.exists?(live_comment.id)
    assert_not Community::CommentContent.exists?(live_content.id)
    assert Community::Post.exists?(restored_post.id)

    replay_id = restored_post.author.deletion_replay_id
    key = "account-deletions/v1/recovery/#{replay_id}.json"
    client.stub_responses(:list_objects_v2, contents: [ { key: } ])
    client.stub_responses(:get_object, body: JSON.generate(account_id: replay_id, recorded_at: Time.current.iso8601))
    replay = Identity::AccountAdministration::ReplayAccountDeletions.new(deletion_log: log)
    assert_equal 1, replay.call
    assert_not Community::Post.exists?(restored_post.id)
    assert_not Community::FilmEndorsement.exists?(restored_endorsement.id)
    assert_not Community::Comment.exists?(restored_comment.id)
    assert_not Community::CommentContent.exists?(restored_content.id)
    assert Registry::Film.exists?(restored_endorsement.film_id)
  end

  test "a member can respond again with more Watched films after endorsing an author's reference" do
    reference = film("The Wicker Grove")
    first = film("A Field at Night")
    later = film("Night Bells")
    comedy = film("Comedy Show", genre: "Comedy")
    curation = publish_with(reference)
    reader = member("curation_respondent")
    [ reference, first, later, comedy ].each { |candidate| watch(reader, candidate) }
    Library::LibraryFilm.new(user: reader, film: film("Still to Watch")).add_to_watchlist!
    sign_in(reader)

    get community_curation_path(curation)
    assert_select "section[aria-labelledby=curation-nominated-films] a[href=?]",
      new_community_curation_response_path(curation), text: I18n.t("community.curation_responses.endorse_films")
    get new_community_curation_response_path(curation)
    assert_response :success
    assert_select ".ui-page-back-above + main.ui-card.ui-narrow"
    assert_select ".ui-page-back-above a[href=?]", community_curation_path(curation), text: I18n.t("community.curation_responses.back")
    assert_select ".community-reference-films > li", count: 3
    assert_select ".community-reference-films > li[data-film-id=?]", reference.id.to_s
    original_activity = curation.updated_at

    travel 1.minute do
      assert_difference({ "Community::FilmEndorsement.count" => 2, "Community::Comment.count" => 2, "Community::CommentContent.count" => 2 }) do
        submit_response(curation, film_ids: [ first.id, reference.id ],
          comments: { first.id => "An isolated setting.", reference.id => "The rituals fit the theme." })
      end
    end
    assert_redirected_to community_curation_path(curation)
    assert_operator curation.reload.updated_at, :>, original_activity
    follow_redirect!
    assert_select ".community-nomination", count: 2 do |items|
      assert_equal [ "nomination-#{reference.id}", "nomination-#{first.id}" ], items.map { |item| item["id"] }
    end
    assert_select "#nomination-#{reference.id} .community-endorsement-badge",
      text: I18n.t("community.curations.endorsements", count: 2)
    assert_select "#nomination-#{reference.id} .community-comment span.community-curation-prompt", text: "The rituals fit the theme."
    assert_select "#nomination-#{first.id} .community-comment span.community-curation-prompt", text: "An isolated setting."

    get new_community_curation_response_path(curation)
    assert_select ".community-reference-films > li", count: 1
    assert_select ".community-reference-films > li[data-film-id=?]", later.id.to_s
    submit_response(curation, film_ids: [ later.id ])
    assert_redirected_to community_curation_path(curation)
    assert_equal [ first.id, reference.id, later.id ].sort,
      curation.film_endorsements.where(user: reader).pluck(:film_id).sort
  end

  test "the author can respond, and repeating a film rejects the entire submission with its title" do
    reference = film("The Original Reference")
    repeated = film("Repeated in the Response")
    kept = film("A Valid Choice")
    curation = publish_with(reference)
    [ repeated, kept ].each { |candidate| watch(@author, candidate) }
    sign_in(@author)
    get new_community_curation_response_path(curation)
    assert_response :success
    assert_select ".community-reference-films > li[data-film-id=?]", reference.id.to_s, count: 0

    [ [ repeated.id, repeated.id, kept.id ], [ reference.id, kept.id ] ].each do |submitted_ids|
      duplicate = submitted_ids.first == repeated.id ? repeated : reference
      assert_no_difference [ "Community::FilmEndorsement.count", "Community::Comment.count", "Community::CommentContent.count" ] do
        submit_response(curation, film_ids: submitted_ids, comments: { kept.id => "Keep this." })
      end
      assert_response :unprocessable_content
      assert_select "ul.ui-errors li", text: /#{Regexp.escape(duplicate.title)}/
      assert_select ".community-selected-films > li[data-film-id=?] textarea", kept.id.to_s, text: "Keep this."
    end

    submit_response(curation, film_ids: [ kept.id ], comments: { kept.id => "Keep this." })
    assert_redirected_to community_curation_path(curation)
    assert curation.film_endorsements.exists?(user: @author, film: kept)
  end

  test "a response submitted after a competing endorsement fails and preserves the other film" do
    competed = film("Night in the Pines")
    kept = film("Hidden Orchard")
    curation = publish_with
    reader = member("stale_respondent")
    [ competed, kept ].each { |candidate| watch(reader, candidate) }
    sign_in(reader)
    get new_community_curation_response_path(curation)
    assert_select ".community-reference-films > li[data-film-id=?]", competed.id.to_s

    result = Community::EndorseCurationFilms.call(curation_id: curation.id, member_id: reader.id, film_ids: [ competed.id ], comments: {})
    assert_empty result.errors
    activity = curation.reload.updated_at
    assert_no_difference [ "Community::FilmEndorsement.count", "Community::Comment.count", "Community::CommentContent.count" ] do
      submit_response(curation, film_ids: [ competed.id, kept.id ], comments: { kept.id => "Keep this too." })
    end
    assert_response :unprocessable_content
    assert_equal activity, curation.reload.updated_at
    assert_select "ul.ui-errors li", text: /Night in the Pines/
    assert_select ".community-reference-films > li[data-film-id=?]", competed.id.to_s, count: 0
    assert_select ".community-selected-films > li[data-film-id=?] textarea", kept.id.to_s, text: "Keep this too."
  end

  test "a film removed from Watched makes a stale response fail without losing the remaining comment" do
    removed = film("Removed from Watched")
    kept = film("Still Watched")
    curation = publish_with
    reader = member("watched_respondent")
    entry = watch(reader, removed)
    watch(reader, kept)
    sign_in(reader)
    get new_community_curation_response_path(curation)
    assert_select ".community-reference-films > li[data-film-id=?]", removed.id.to_s

    Library::CollectionManagement::RemoveFromWatched.call(user_id: reader.id, library_film_id: entry.id)
    activity = curation.reload.updated_at
    assert_no_difference [ "Community::FilmEndorsement.count", "Community::Comment.count", "Community::CommentContent.count" ] do
      submit_response(curation, film_ids: [ removed.id, kept.id ], comments: { removed.id => "Discard this.", kept.id => "Keep this." })
    end
    assert_response :unprocessable_content
    assert_equal activity, curation.reload.updated_at
    assert_select "ul.ui-errors li", text: /no longer eligible/
    assert_select ".community-selected-films > li[data-film-id=?]", removed.id.to_s, count: 0
    assert_select ".community-selected-films > li[data-film-id=?] textarea", kept.id.to_s, text: "Keep this."
  end

  test "responses require one to five film IDs" do
    curation = publish_with
    films = 6.times.map { |index| film("Watched film #{index + 1}") }
    films.each { |candidate| watch(@author, candidate) }
    sign_in(@author)
    get new_community_curation_response_path(curation)

    [ [], films.map(&:id) ].each do |ids|
      assert_no_difference "Community::FilmEndorsement.count" do
        submit_response(curation, film_ids: ids)
      end
      assert_response :unprocessable_content
      assert_select "ul.ui-errors li", text: /one and 5 films/
    end

    assert_difference "Community::FilmEndorsement.count", 5 do
      submit_response(curation, film_ids: films.first(5).map(&:id))
    end
    assert_redirected_to community_curation_path(curation)
  end

  test "response links and requests require posting access" do
    curation = publish_with
    [ member("respond_no_conduct", accepted: false), member("respond_no_name", username: false),
      member("respond_no_avatar", avatar: false), member("respond_outside_preview", superuser: false) ].each do |viewer|
      sign_in(viewer)
      get library_path
      assert_no_difference "Community::FilmEndorsement.count" do
        submit_response(curation, film_ids: [ 1 ])
      end
      assert_response :forbidden
      get new_community_curation_response_path(curation)
      assert_response :forbidden
      get community_curation_path(curation)
      assert_select "a[href=?]", new_community_curation_response_path(curation), count: 0 if viewer.superuser?
    end
  end

  test "the author can revise only the curation text after another member contributes" do
    reference = film("A Tale in the Woods")
    curation = publish_with(reference)
    reader = member("reader_before_edit")
    watch(reader, reference)
    Community::EndorseCurationFilms.call(curation_id: curation.id, member_id: reader.id, film_ids: [ reference.id ],
      comments: { reference.id => "The forest is central to the film." })
    saved_title = curation.title
    saved_prompt = curation.prompt
    activity = curation.reload.updated_at
    path = community_curation_path(curation)
    sign_in(@author)

    get path
    assert_select "a[href=?]", edit_community_curation_path(curation), text: I18n.t("community.curation_editing.edit_post")
    get edit_community_curation_path(curation)
    assert_response :success
    assert_select "#curation_title[value=?]", saved_title
    assert_select "#curation_prompt", text: saved_prompt
    assert_select ".community-reference-picker", count: 0

    patch path, params: { authenticity_token: curation_action_token(path), curation: { title: " ", prompt: "Keep this draft." } }
    assert_response :unprocessable_content
    assert_select "ul.ui-errors li"
    assert_select "#curation_prompt", text: "Keep this draft."
    curation.reload
    assert_equal [ saved_title, saved_prompt ], [ curation.title, curation.prompt ]

    travel 1.minute do
      assert_no_difference [ "Community::FilmEndorsement.count", "Community::Comment.count", "Community::CommentContent.count" ] do
        patch path, params: { authenticity_token: curation_action_token(path),
          curation: { title: "  Forest horror  ", prompt: "Films with an uneasy woodland setting.", author_id: reader.id, reference_film_ids: [] } }
      end
    end
    assert_redirected_to path
    assert_equal @author, curation.reload.author
    assert_equal activity, curation.updated_at
    follow_redirect!
    assert_select "h1", text: "Forest horror"
    assert_select "p.community-curation-prompt", text: "Films with an uneasy woodland setting."
    assert_select "#nomination-#{reference.id} .community-endorsement-badge", text: I18n.t("community.curations.endorsements", count: 2)
    assert_select "#nomination-#{reference.id} .community-comment span.community-curation-prompt", text: "The forest is central to the film."
  end

  test "other members cannot edit or delete an author's curation" do
    curation = publish_with
    path = community_curation_path(curation)
    sign_in(member("different_member"))

    get path
    assert_response :success
    assert_select "a[href=?]", edit_community_curation_path(curation), count: 0
    assert_select "button", text: I18n.t("community.curation_deletion.delete_post"), count: 0
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]

    get edit_community_curation_path(curation)
    assert_response :forbidden
    patch path, params: { authenticity_token: token, curation: { title: "Someone else's edit", prompt: "Unwanted changes." } }
    assert_response :forbidden
    assert_equal "Slow-burn horror", curation.reload.title

    assert_no_difference "Community::Post.count" do
      delete path, params: { authenticity_token: token }
    end
    assert_response :forbidden
  end

  test "an author can delete a curation and its contributions without changing Library or Registry" do
    reference = film("The Hollow Oak")
    curation = publish_with(reference)
    reader = member("reader_before_deletion")
    watched_entry = watch(reader, reference)
    Community::EndorseCurationFilms.call(curation_id: curation.id, member_id: reader.id, film_ids: [ reference.id ],
      comments: { reference.id => "The oak anchors the story." })
    root = curation.comments.sole
    reply = Community::PublishCurationReply.call(curation_id: curation.id, comment_id: root.id, member_id: @author.id,
      body: "It anchors the setting too.").fetch(:reply).comment
    Community::PublishCurationReply.call(curation_id: curation.id, comment_id: reply.id, member_id: reader.id,
      body: "I agree about the setting.")
    path = community_curation_path(curation)
    sign_in(@author)

    get path
    assert_select "dialog[aria-labelledby=delete-curation-title]", text: /permanently deletes/
    assert_difference({ "Community::Post.count" => -1, "Community::FilmEndorsement.count" => -2,
                        "Community::Comment.count" => -3, "Community::CommentContent.count" => -3 }) do
      delete path, params: { authenticity_token: curation_action_token(path) }
    end
    assert_redirected_to community_path
    assert_not Community::Post.exists?(curation.id)
    assert Registry::Film.exists?(reference.id)
    assert Library::LibraryFilm.watched.exists?(watched_entry.id)
  end

  test "publishing a reply groups it with its parent and refreshes discussion activity" do
    curation, root = curation_with_comment
    reference = root.film_endorsement.film
    member = member("reply_member")
    sign_in(member)
    activity = curation.updated_at

    get new_community_curation_comment_reply_path(curation, root)
    assert_response :success
    path = community_curation_comment_reply_path(curation, root)
    body = "x" * Community::CommentContent::REPLY_LIMIT
    travel 1.minute do
      assert_difference({ "Community::Comment.count" => 1, "Community::CommentContent.count" => 1,
                          "Community::FilmEndorsement.count" => 0 }) do
        post path, params: { authenticity_token: curation_action_token(path), body: }
      end
    end

    reply = curation.comments.find_by!(parent_id: root.id)
    assert_equal root.id, reply.root_id
    assert_equal member, reply.content.author
    assert_equal body, reply.content.body
    assert_operator curation.reload.updated_at, :>, activity
    assert_redirected_to community_curation_path(curation, reply: reply.id, anchor: "comment-#{reply.id}")
    follow_redirect!
    assert_select "#nomination-#{reference.id} .community-endorsement-badge", text: I18n.t("community.curations.endorsements", count: 1)
    assert_select "#nomination-#{reference.id} details.community-film-comments[open] > summary", text: I18n.t("community.curations.comments", count: 2)
    assert_select "#replies-#{root.id}[open] > .community-comment-thread > #comment-#{reply.id}", text: /#{body}/

    get community_path
    assert_select ".community-curation-card-counts li", text: I18n.t("community.curations.comments", count: 2)
  end

  test "reply submissions reject oversized or blank text without saving comment structure" do
    curation, root = curation_with_comment
    sign_in(member("reply_validator"))
    path = community_curation_comment_reply_path(curation, root)
    get new_community_curation_comment_reply_path(curation, root)
    activity = curation.updated_at

    oversized_body = "x" * (Community::CommentContent::REPLY_LIMIT + 1)
    [ oversized_body, "" ].each do |body|
      assert_no_difference [ "Community::Comment.count", "Community::CommentContent.count" ] do
        post path, params: { authenticity_token: curation_action_token(path), body: }
      end
      assert_response :unprocessable_content
      assert_select ".ui-errors li"
      assert_select "textarea#comment-composer-#{root.id}-body", text: body
    end
    assert_equal activity, curation.reload.updated_at
  end

  test "a member without posting access cannot open or submit a reply" do
    curation, root = curation_with_comment
    sign_in(member("reply_reader", accepted: false))
    get community_curation_path(curation)
    assert_select "a[href=?]", new_community_curation_comment_reply_path(curation, root), count: 0
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]

    get new_community_curation_comment_reply_path(curation, root)
    assert_response :forbidden
    assert_no_difference [ "Community::Comment.count", "Community::CommentContent.count" ] do
      post community_curation_comment_reply_path(curation, root), params: { authenticity_token: token, body: "An unauthorized reply." }
    end
    assert_response :forbidden
  end

  test "a reply target from another curation cannot be used in a direct request" do
    curation, root = curation_with_comment
    other = publish_with
    sign_in(member("reply_other_curation"))
    get new_community_curation_comment_reply_path(curation, root)
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]

    get new_community_curation_comment_reply_path(other, root)
    assert_response :not_found
    assert_no_difference [ "Community::Comment.count", "Community::CommentContent.count" ] do
      post community_curation_comment_reply_path(other, root), params: { authenticity_token: token, body: "A mismatched reply." }
    end
    assert_response :not_found
  end

  test "a reply submitted after its curation was deleted fails without recreating anything" do
    curation, root = curation_with_comment
    sign_in(member("reply_stale_target"))
    get new_community_curation_comment_reply_path(curation, root)
    path = community_curation_comment_reply_path(curation, root)
    token = curation_action_token(path)

    Community::DeleteCuration.call(curation_id: curation.id, member_id: @author.id)
    assert_no_difference [ "Community::Post.count", "Community::Comment.count", "Community::CommentContent.count" ] do
      post path, params: { authenticity_token: token, body: "A stale reply." }
    end
    assert_response :not_found
  end

  test "authors can edit an opening comment and reply without changing board activity" do
    curation, root = curation_with_comment
    reply = Community::PublishCurationReply.call(curation_id: curation.id, comment_id: root.id, member_id: @author.id,
      body: "My original reply.").fetch(:reply).comment
    activity = curation.reload.updated_at
    sign_in(@author)
    limit = Community::CommentContent::REPLY_LIMIT
    long_body = "a" * (limit + 1)

    get edit_community_curation_comment_path(curation, root)
    root_path = community_curation_comment_path(curation, root)
    assert_select "textarea[name=body]:not([maxlength])", text: root.content.body
    travel 1.minute do
      patch root_path, params: { authenticity_token: curation_action_token(root_path), body: long_body }
    end
    assert_redirected_to community_curation_path(curation, reply: root.id, anchor: "comment-#{root.id}")
    assert_equal long_body, root.content.reload.body

    get edit_community_curation_comment_path(curation, reply)
    reply_path = community_curation_comment_path(curation, reply)
    assert_select "textarea[name=body][maxlength=?]", limit.to_s, text: "My original reply."
    patch reply_path, params: { authenticity_token: curation_action_token(reply_path), body: long_body }
    assert_response :unprocessable_content
    assert_select ".ui-errors li"
    assert_select "textarea[name=body]", text: long_body
    assert_equal "My original reply.", reply.content.reload.body

    travel 1.minute do
      patch reply_path, params: { authenticity_token: curation_action_token(reply_path), body: "My updated reply." }
    end
    assert_redirected_to community_curation_path(curation, reply: reply.id, anchor: "comment-#{reply.id}")
    assert_equal "My updated reply.", reply.content.reload.body
    assert_equal root.id, reply.reload.parent_id
    assert_equal activity, curation.reload.updated_at
  end

  test "other members cannot edit or delete an authored comment" do
    curation, root = curation_with_comment
    path = community_curation_comment_path(curation, root)
    sign_in(member("other_comment_author"))
    get community_curation_path(curation)
    assert_select "a[href=?]", edit_community_curation_comment_path(curation, root), count: 0
    assert_select "form[action=?]", path, count: 0
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]

    get edit_community_curation_comment_path(curation, root)
    assert_response :forbidden
    patch path, params: { authenticity_token: token, body: "Someone else's edit." }
    assert_response :forbidden
    delete path, params: { authenticity_token: token }
    assert_response :forbidden
    assert_equal "A quiet setting.", root.content.reload.body
  end

  test "deleting an opening comment removes a leaf without removing its endorsement" do
    curation, root = curation_with_comment
    reader = member("stale_comment_reply")
    sign_in(reader)
    get new_community_curation_comment_reply_path(curation, root)
    reply_path = community_curation_comment_reply_path(curation, root)
    reply_token = curation_action_token(reply_path)
    reply_cookie = cookies[:session_id]

    sign_in(@author)
    get community_curation_path(curation)
    delete_path = community_curation_comment_path(curation, root)
    activity = curation.updated_at
    travel 1.minute do
      assert_difference({ "Community::Comment.count" => -1, "Community::CommentContent.count" => -1,
                          "Community::FilmEndorsement.count" => 0 }) do
        delete delete_path, params: { authenticity_token: curation_action_token(delete_path) }
      end
    end
    assert_redirected_to community_curation_path(curation, anchor: "nomination-#{root.film_endorsement.film_id}")
    assert_equal activity, curation.reload.updated_at

    cookies[:session_id] = reply_cookie
    assert_no_difference [ "Community::Comment.count", "Community::CommentContent.count" ] do
      post reply_path, params: { authenticity_token: reply_token, body: "Too late." }
    end
    assert_response :not_found
  end

  test "a reply committed before deletion survives under an unreplyable marker" do
    curation, root = curation_with_comment
    reader = member("surviving_reply_author")
    sign_in(@author)
    get community_curation_path(curation)
    path = community_curation_comment_path(curation, root)
    token = curation_action_token(path)
    reply = Community::PublishCurationReply.call(curation_id: curation.id, comment_id: root.id, member_id: reader.id,
      body: "The mood also helps.").fetch(:reply).comment
    activity = curation.reload.updated_at

    travel 1.minute do
      assert_difference({ "Community::Comment.count" => 0, "Community::CommentContent.count" => -1,
                          "Community::FilmEndorsement.count" => 0 }) do
        delete path, params: { authenticity_token: token }
      end
    end
    assert_redirected_to community_curation_path(curation, reply: root.id, anchor: "comment-#{root.id}")
    assert_nil root.reload.content
    assert_equal root.id, reply.reload.parent_id
    assert_equal activity, curation.reload.updated_at
    follow_redirect!
    assert_select "#comment-#{root.id}", text: I18n.t("community.curation_replies.removed")
    assert_select "#comment-#{root.id} a, #comment-#{root.id} strong", count: 0
    assert_select "#replies-#{root.id}[open] #comment-#{reply.id}", text: /The mood also helps/
    assert_select "#film-comment-count-#{root.film_endorsement.film_id}", text: I18n.t("community.curations.comments", count: 1)
    marker_token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]

    get new_community_curation_comment_reply_path(curation, root)
    assert_response :not_found
    assert_no_difference [ "Community::Comment.count", "Community::CommentContent.count" ] do
      post community_curation_comment_reply_path(curation, root), params: { authenticity_token: marker_token, body: "A reply to the marker." }
    end
    assert_response :not_found
    get new_community_curation_comment_reply_path(curation, reply)
    assert_response :success

    get community_path
    assert_select ".community-curation-card-counts li", text: I18n.t("community.curations.comments", count: 1)
  end

  private

  def curation_with_comment
    reference = film("A film with a discussion")
    watch(@author, reference)
    curation = Community::PublishCuration.call(author_id: @author.id, title: "Films with a quiet setting",
      prompt: "Set in small communities.", reference_film_ids: [ reference.id ], reference_comments: { reference.id => "A quiet setting." })
    [ curation, curation.comments.sole ]
  end

  def member(name, accepted: true, username: true, avatar: true, superuser: true)
    Identity::UserRegistered.create!(email_address: "#{name}@example.test", password: PASSWORD,
      password_confirmation: PASSWORD, email_confirmed_at: Time.current, superuser:,
      community_code_of_conduct_version: (Community::CodeOfConduct.current.version if accepted),
      community_code_of_conduct_accepted_at: (Time.current if accepted),
      community_username: (name if username), community_avatar_preset: ("moth" if avatar))
  end

  def sign_in(user)
    authentication = Identity::Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def film(title, genre: "Horror")
    Registry::Film.create!(title:, tmdb_metadata: { details: { genres: [ { name: genre } ] } })
  end

  def watch(user, film)
    Library::LibraryFilm.new(user:, film:).add_to_watched!
  end

  def publish_with(*films)
    films.each { |film| watch(@author, film) }
    Community::PublishCuration.call(author_id: @author.id, title: "Slow-burn horror", prompt: "Films for this theme.",
      reference_film_ids: films.map(&:id), reference_comments: {})
  end

  def nomination_form(path, film:)
    form = Nokogiri::HTML(response.body).at_css("#nomination-#{film.id} form[action='#{path}']")
    { authenticity_token: form.at_css("input[name=authenticity_token]")["value"], film_id: form.at_css("input[name=film_id]")["value"] }
  end

  def submit_curation(**fields)
    page = Nokogiri::HTML(response.body)
    token = page.at_css("form[action='#{community_curations_path}'] input[name=authenticity_token]")&.[]("value")
    token ||= page.at_css('meta[name="csrf-token"]')["content"]
    curation = { title: "Slow-burn modern folk horror", prompt: "Stories that take their time." }.merge(fields)
    post community_curations_path, params: { authenticity_token: token, curation: }
  end

  def submit_response(curation, film_ids:, comments: {})
    path = community_curation_response_path(curation)
    page = Nokogiri::HTML(response.body)
    token = page.at_css("form[action='#{path}'] input[name=authenticity_token]")&.[]("value")
    token ||= page.at_css('meta[name="csrf-token"]')["content"]
    fields = { film_ids: film_ids.presence, comments: comments.presence }.compact
    post path, params: { authenticity_token: token, response: fields }
  end

  def curation_action_token(path)
    Nokogiri::HTML(response.body).at_css("form[action='#{path}'] input[name=authenticity_token]")["value"]
  end
end
