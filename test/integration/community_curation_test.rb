require "test_helper"

class CommunityCurationTest < ActionDispatch::IntegrationTest
  PASSWORD = "a long test password"

  setup do
    controllers = [ Community::PostsController, Community::CurationEndorsementsController, Community::PostCommentsController, Community::BoardController, LibraryController ]
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
      new_community_post_path, text: I18n.t("community.curations.create")
    assert_select "nav.community-board-pagination > span", text: I18n.t("community.pagination.page", number: 1)
    get new_community_post_path
    assert_response :success
    assert_select "main.ui-card.community-curation-form"
    assert_select ".ui-page-back-above", count: 0
    assert_select ".ui-actions a[href=?]", community_path, text: I18n.t("community.curations.cancel")
    assert_select "#curation_title[aria-describedby=curation_title_hint]"
    assert_select "#curation_title_hint", text: I18n.t("community.curations.title_hint")
    assert_select "label[for=curation_description]", text: I18n.t("community.curations.description")
    assert_select "#curation_description[aria-describedby=curation_description_hint] + #curation_description_hint",
      text: I18n.t("community.curations.description_hint")
    assert_select "#curation_reference_search[placeholder=?]", I18n.t("community.curations.search_watched")
    assert_select ".community-reference-picker > legend > #curation_reference_hint",
      text: I18n.t("community.curations.reference_hint")
    assert_select ".community-reference-picker #curation_reference_search[aria-describedby=curation_reference_hint]"
    assert_select ".film-search-dropdown[hidden] .film-search-results > li", count: 2
    assert_select ".film-search-results > li[data-film-id=?]", first.id.to_s
    assert_select ".film-search-results > li[data-film-id=?]", second.id.to_s
    assert_select "input[name*=tag], select[name*=tag]", count: 0

    assert_difference "Community::PostCommunityCuration.count", 1 do
      submit_curation(reference_film_ids: [ first.id, second.id ],
        reference_comments: { first.id.to_s => "The sense of dread builds slowly.", second.id.to_s => " " }, tag: "Film Debrief")
    end
    assert_response :see_other
    curation = Community::PostCommunityCuration.find_by!(title: "Slow-burn modern folk horror")
    assert_redirected_to community_post_path(curation)
    assert_equal @author.community_user, curation.community_user
    assert_equal [ [ second.id, @author.id ], [ first.id, @author.id ] ].sort,
      curation.film_endorsements.pluck(:film_id, :user_id).sort
    comment = curation.film_endorsements.find_by!(film: first).comments.sole
    assert_equal curation, comment.post
    assert_equal @author.community_user, comment.content.community_user
    assert_equal "The sense of dread builds slowly.", comment.content.body
    assert_empty curation.film_endorsements.find_by!(film: second).comments

    follow_redirect!
    assert_select "h1", curation.title
    assert_select ".ui-page-back-above + main.community-curation-page.ui-card"
    assert_select ".ui-page-back-above a[href=?]", community_path, text: I18n.t("community.curations.back")
    assert_select ".community-curation-prompt", "Stories that take their time."
    assert_select ".community-post-tag > span:first-child", text: I18n.t("community.curations.tag"), count: 1
    assert_select ".community-post-tag > [role=tooltip]", text: I18n.t("community.curations.tag_tooltip")
    assert_select ".community-post-tags + .community-curation-author", text: @author.community_user&.community_username do
      assert_select "img[src*=?][alt='']", "community-avatars/#{@author.community_user&.community_avatar_preset}"
    end
    assert_select ".community-curation-author + .community-curation-descriptions", count: 1
    assert_select "h2.sr-only", I18n.t("community.curations.nominated_films")
    assert_select "ol.community-nominations > li" do |rows|
      assert_equal [ second.title, first.title ], rows.map { |row| row.at_css("h3").text }
    end
    assert_select "p", text: I18n.t("community.curations.endorsement_order")
    assert_select ".community-endorsement-badge", text: I18n.t("community.curations.endorsements", count: 1), count: 2
    assert_select "#nomination-#{first.id} details:not([open])" do
      assert_select "summary", text: I18n.t("community.curations.comments", count: 1)
      assert_select "article", count: 0
    end
    assert_select "#nomination-#{second.id}" do
      assert_select "p.community-comment-count", text: I18n.t("community.curations.comments", count: 0)
      assert_select "details", count: 0
    end
    get discussion_community_post_path(curation, film_id: first.id)
    assert_select "article span.community-curation-prompt", text: "The sense of dread builds slowly."
    assert_select "article strong", text: @author.community_user&.community_username
    assert_select "article a", text: I18n.t("community.curations.reply")
    assert_select "article button[disabled]", text: "Report", count: 0

    sign_in(member("preview_reader", accepted: false, username: false, avatar: false))
    get community_path
    assert_select "a.community-curation-card[href=?]", community_post_path(curation), count: 1 do |links|
      assert_select "h2[id=?]", links.first["aria-labelledby"], text: curation.title
      assert_select "p", text: curation.description, count: 0
      assert_select "footer .community-curation-card-counts + .community-curation-card-author", text: @author.community_user&.community_username do
        assert_select "img[src*=?] + strong", "community-avatars/#{@author.community_user&.community_avatar_preset}", text: @author.community_user&.community_username
      end
      assert_select ".community-post-card-heading h2 + .community-post-tags .community-post-tag > span:first-child", text: I18n.t("community.curations.tag")
      assert_select ".community-post-card-heading [role=tooltip], .community-post-card-heading .community-post-tag[aria-describedby]", count: 0
      assert_select "time", count: 0
      assert_select "footer .community-curation-card-counts li", text: I18n.t("community.curations.films", count: 2)
      assert_select "footer .community-curation-card-counts li", text: I18n.t("community.curations.endorsements", count: 2)
      assert_select "footer .community-curation-card-counts li", text: I18n.t("community.curations.comments", count: 1)
      assert_select ".community-curation-card-posters .film-poster", count: 2
    end
    assert_select ".community-post-tag > span:first-child", text: I18n.t("community.curations.tag"), count: 1
    assert_select "a[href=?]", new_community_post_path, count: 0
    get community_post_path(curation)
    assert_response :success
  end

  test "publishes with no reference films" do
    sign_in(@author)
    get new_community_post_path
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

    get community_post_path(curation)
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

    get community_post_path(curation)
    watchlist_path = community_curation_film_watchlist_path(curation, first)
    watched_path = community_curation_film_watched_path(curation, first)
    post watchlist_path, params: { authenticity_token: curation_action_token(watchlist_path) }
    assert_redirected_to community_post_path(curation)
    assert Library::LibraryFilm.watchlist.exists?(user: viewer, film: first)
    assert_library_events(viewer, first, Library::Events::FILM_ADDED_TO_WATCHLIST)

    follow_redirect!
    assert_select "#nomination-#{first.id} button[aria-label=?][aria-disabled=true][data-in-collection=true]", I18n.t("library.search.in_watchlist")
    post watched_path, params: { authenticity_token: curation_action_token(watched_path) }
    assert_redirected_to community_post_path(curation)
    assert Library::LibraryFilm.watched.exists?(user: viewer, film: first)
    assert_library_events(viewer, first, Library::Events::FILM_ADDED_TO_WATCHLIST, Library::Events::FILM_MARKED_WATCHED)

    follow_redirect!
    assert_select "#nomination-#{first.id} .community-nomination-media" do
      assert_select "button[aria-label=?][aria-disabled=true][data-in-collection=true]", I18n.t("library.search.in_watched")
      assert_select "button[aria-label=?][aria-disabled=true]:not([data-in-collection])", I18n.t("community.curations.watchlist_unavailable_when_watched")
      assert_select "form", count: 0
    end
    watched_path = community_curation_film_watched_path(curation, second)
    post watched_path, params: { authenticity_token: curation_action_token(watched_path) }
    assert_redirected_to community_post_path(curation)
    assert Library::LibraryFilm.watched.exists?(user: viewer, film: second)
    assert_library_events(viewer, second, Library::Events::FILM_MARKED_WATCHED)
    assert_equal 2, curation.film_endorsements.count
    assert_equal activity_at, curation.reload.updated_at
  end

  test "curation Library submissions reject unrelated films, stale actions and unauthorised viewers" do
    nominated = film("A Nomination")
    unrelated = film("Unrelated Film")
    curation = publish_with(nominated)
    viewer = member("library_reader")
    sign_in(viewer)
    path = community_curation_film_watchlist_path(curation, nominated)
    get community_post_path(curation)
    token = curation_action_token(path)
    page_token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]

    assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
      post community_curation_film_watchlist_path(curation, unrelated), params: { authenticity_token: page_token }
    end
    assert_response :not_found

    Library::CollectionManagement::AddToWatchlist.call(user_id: viewer.id, film_id: nominated.id)
    assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
      post path, params: { authenticity_token: token }
    end
    assert_redirected_to community_post_path(curation)
    assert_equal I18n.t("community.curations.library_action_unavailable"), flash[:alert]

    follow_redirect!
    watched_path = community_curation_film_watched_path(curation, nominated)
    watched_token = curation_action_token(watched_path)
    entry = Library::CollectionManagement::MarkWatched.call(user_id: viewer.id, film_id: nominated.id)
    assert_no_changes -> { entry.reload.watched_at } do
      assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
        post watched_path, params: { authenticity_token: watched_token }
      end
    end
    assert_redirected_to community_post_path(curation)
    assert_equal I18n.t("community.curations.library_action_unavailable"), flash[:alert]

    sign_in(Identity::UserGuest.create!)
    get library_path
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
    assert_no_difference "Library::LibraryFilm.count" do
      post path, params: { authenticity_token: token }
    end
    assert_response :forbidden
  end

  test "both Library actions reject a nomination withdrawn after the form was opened" do
    nominated = film("A Withdrawn Nomination")
    curation = publish_with(nominated)
    viewer = member("stale_nomination_reader")
    sign_in(viewer)
    get community_post_path(curation)
    paths = [ community_curation_film_watchlist_path(curation, nominated), community_curation_film_watched_path(curation, nominated) ]
    tokens = paths.index_with { |path| curation_action_token(path) }

    save_endorsements(curation, member: @author, film_ids: [])

    tokens.each do |path, token|
      assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
        post path, params: { authenticity_token: token }
      end
      assert_response :not_found
    end
  end

  test "the board lists ten posts at a time with a stable order for equal update timestamps" do
    freeze_time do
      12.times do |index|
        Community::Curations::PublishCuration.call(community_user: @author.community_user, title: "Curation #{index + 1}",
          description: "Films for this theme.", reference_film_ids: [], reference_comments: {})
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
      Community::Curations::PublishCuration.call(community_user: @author.community_user, title: (index.zero? ? matching_title : "Curation #{index}"),
        description: (index.zero? ? "Selected by title." : "More Folk% Horror films."), reference_film_ids: [], reference_comments: {})
    end
    Community::Curations::PublishCuration.call(community_user: @author.community_user, title: "Folk tale horror", description: "Unrelated wording.",
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

  test "the board sorts curations by latest update" do
    created_at = Time.zone.local(2026, 11, 20, 9, 15)
    updated_at = Time.zone.local(2026, 11, 23, 14, 30)
    earlier_post = Community::PostCommunityCuration.create!(community_user: @author.community_user, title: "Slow-burn horror", description: "Films for this theme.",
      created_at:, updated_at:)
    newer_post = Community::PostCommunityCuration.create!(community_user: @author.community_user, title: "Folk horror", description: "Films for this theme.",
      created_at: Time.zone.local(2026, 11, 21, 9, 15), updated_at: Time.zone.local(2026, 11, 22, 14, 30))
    sign_in(@author)

    get community_path
    assert_select ".community-curation-card h2" do |titles|
      assert_equal [ earlier_post.title, newer_post.title ], titles.map(&:text)
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
    assert_select ".community-curation-card[href=?]", community_post_path(matching_curation)
    assert_select ".community-curation-card[href=?]", community_post_path(unrelated_curation), count: 0

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
      get new_community_post_path
      assert_select ".film-search-results > li", count: 1
      assert_select ".film-search-results > li[data-film-id=?]", valid.id.to_s
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
    get new_community_post_path
    assert_select ".film-search-results > li[data-film-id=?]", reference.id.to_s

    Library::CollectionManagement::RemoveFromWatched.call(user_id: @author.id, library_film_id: entry.id)
    assert_no_difference [ "Community::Post.count", "Community::FilmEndorsement.count" ] do
      submit_curation(reference_film_ids: [ reference.id ])
    end
    assert_response :unprocessable_content
  end

  test "validates text limits and distinct references while allowing more than five" do
    sign_in(@author)
    get new_community_post_path
    assert_no_difference "Community::Post.count" do
      submit_curation(title: "a" * 121, description: "b" * 2001, reference_film_ids: [ 1, 1, 2, 3, 4, 5 ])
    end
    assert_response :unprocessable_content
    assert_select "ul.ui-errors li", count: 3

    films = 6.times.map { |index| film("Reference #{index + 1}") }
    films.each { |candidate| watch(@author, candidate) }
    get new_community_post_path
    assert_difference "Community::FilmEndorsement.count", 6 do
      submit_curation(reference_film_ids: films.map(&:id))
    end
    assert_response :see_other

    get new_community_post_path
    assert_no_difference "Community::Post.count" do
      submit_curation(title: " ", description: " ")
    end
    assert_response :unprocessable_content
    assert_select "ul.ui-errors li", count: 2
  end

  test "requires a flat array of valid reference IDs" do
    sign_in(@author)
    get new_community_post_path
    assert_no_difference "Community::Post.count" do
      submit_curation(reference_film_ids: "3")
    end
    assert_response :bad_request
  end

  test "rejects a comment for a reference that was not selected" do
    sign_in(@author)
    get new_community_post_path
    assert_no_difference [ "Community::Post.count", "Community::Comment.count", "Community::CommentContent.count" ] do
      submit_curation(reference_comments: { "3" => "A comment without a reference." })
    end
    assert_response :bad_request
  end

  test "incomplete Community setup blocks publication" do
    [
      member("no_profile", accepted: false, username: false, avatar: false),
      member("no_conduct", accepted: false),
      member("no_name", username: false),
      member("no_avatar", avatar: false)
    ].each do |viewer|
      sign_in(viewer)
      get community_path
      assert_response :success
      assert_select "a[href=?]", new_community_post_path, count: 0
      assert_no_difference "Community::Post.count" do
        submit_curation
      end
      assert_response :forbidden
      get new_community_post_path
      assert_response :forbidden
    end
  end

  test "guests cannot access or publish curations directly" do
    sign_in(@author)
    get new_community_post_path
    submit_curation
    curation = Community::PostCommunityCuration.find_by!(community_user: @author.community_user)
    sign_in(Identity::UserGuest.create!)
    get library_path
    assert_no_difference "Community::Post.count" do
      submit_curation
    end
    assert_response :forbidden
    [ community_path, new_community_post_path, community_post_path(curation) ].each do |path|
      get path
      assert_response :forbidden
    end
  end

  test "account closure and deletion replay remove curations and initial endorsements" do
    [ @author, member("restored_author") ].each do |author|
      reference = film("A Reference for #{author.community_user&.community_username}")
      watch(author, reference)
      sign_in(author)
      get new_community_post_path
      submit_curation(reference_film_ids: [ reference.id ], reference_comments: { reference.id.to_s => "It fits the theme." })
      assert_response :see_other
    end
    live_post, restored_post = Community::PostCommunityCuration.order(:id).to_a
    live_endorsement = live_post.film_endorsements.sole
    restored_endorsement = restored_post.film_endorsements.sole
    live_comment = live_endorsement.comments.sole
    restored_comment = restored_endorsement.comments.sole
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

    replay_id = restored_post.community_user.user.deletion_replay_id
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

  %i[closure replay].each do |path|
    test "account #{path} preserves protected posts authored by the departing member" do
      curation, root = curation_with_comment
      reference = root.film_endorsement.film
      reader = protect_with_endorsements(curation, reference).first
      reply = Community::Discussions::PublishCurationReply.call(curation_id: curation.id, comment_id: root.id, community_user: reader.community_user,
        body: "A reply from another member.").fetch(:reply).comment
      Community::Curations::ManageCurationAuthorship.update_description(curation_id: curation.id, community_user: @author.community_user,
        additional_description: "An additional description that stays.")
      unprotected = publish_with
      client = Aws::S3::Client.new(region: "auto", stub_responses: true)
      log = Identity::AccountAdministration::DeletionLog.new(client:, bucket: "fixture", namespace: "recovery")

      if path == :closure
        Identity::AccountAdministration::ManageRegisteredAccount.new(user_id: @author.id).close_account(deletion_log: log)
      else
        replay_id = @author.deletion_replay_id
        key = "account-deletions/v1/recovery/#{replay_id}.json"
        client.stub_responses(:list_objects_v2, contents: [ { key: } ])
        client.stub_responses(:get_object, body: JSON.generate(account_id: replay_id, recorded_at: Time.current.iso8601))
        replay = Identity::AccountAdministration::ReplayAccountDeletions.new(deletion_log: log)
        assert_equal 1, replay.call
        assert_equal 0, replay.call
      end

      assert_not Community::Post.exists?(unprotected.id)
      assert curation.reload.protected?
      assert_nil curation.community_user
      assert_nil root.reload.content
      assert_equal 3, curation.film_endorsements.active.count
      assert_equal "An additional description that stays.", curation.additional_description
      sign_in(reader)
      get community_post_path(curation, reply: reply.id)
      assert_select "p.community-curation-prompt", text: "Set in small communities."
      assert_select "#comment-#{root.id}", text: I18n.t("community.curation_replies.removed")
      assert_select "#comment-#{reply.id}", text: /A reply from another member/
    end

    test "account #{path} preserves other members' replies on a surviving curation" do
      curation = publish_with
      nominated = film("Woodland apparitions")
      no_replies = film("Night of the Pines")
      endorser = member("retired_endorser")
      reader = member("surviving_reader")
      [ nominated, no_replies ].each { |candidate| watch(endorser, candidate) }
      save_endorsements(curation, member: endorser, film_ids: [ nominated.id, no_replies.id ],
        comments: { nominated.id => "Opening text to remove.", no_replies.id => "An unanswered opening." })
      root = curation.film_endorsements.find_by!(film: nominated).comments.sole
      content_id = root.content.id
      reply = Community::Discussions::PublishCurationReply.call(curation_id: curation.id, comment_id: root.id, community_user: reader.community_user,
        body: "A reply that stays.").fetch(:reply).comment
      client = Aws::S3::Client.new(region: "auto", stub_responses: true)
      log = Identity::AccountAdministration::DeletionLog.new(client:, bucket: "fixture", namespace: "recovery")

      if path == :closure
        Identity::AccountAdministration::ManageRegisteredAccount.new(user_id: endorser.id).close_account(deletion_log: log)
      else
        replay_id = endorser.deletion_replay_id
        key = "account-deletions/v1/recovery/#{replay_id}.json"
        client.stub_responses(:list_objects_v2, contents: [ { key: } ])
        client.stub_responses(:get_object, body: JSON.generate(account_id: replay_id, recorded_at: Time.current.iso8601))
        assert_equal 1, Identity::AccountAdministration::ReplayAccountDeletions.new(deletion_log: log).call
      end

      assert_not Identity::User.exists?(endorser.id)
      assert_not Community::CommentContent.exists?(content_id)
      assert_equal root.id, reply.reload.parent_id
      assert_not curation.film_endorsements.active.exists?
      sign_in(reader)
      get community_post_path(curation, reply: reply.id)
      assert_select "#nomination-#{nominated.id} .community-endorsement-badge", text: I18n.t("community.curations.endorsements", count: 0)
      assert_select "#nomination-#{no_replies.id}", count: 0
      assert_select "#comment-#{root.id}", text: I18n.t("community.curation_replies.removed")
      assert_select "#comment-#{reply.id}", text: /A reply that stays/
      refute_includes response.body, "Opening text to remove."
      get new_reply_community_post_comment_path(curation, reply)
      assert_response :success
    end
  end

  test "a member starts with an empty editor and can edit their own saved endorsements" do
    reference = film("The Wicker Grove")
    first = film("A Field at Night")
    later = film("Night Bells")
    comedy = film("Comedy Show", genre: "Comedy")
    curation = publish_with(reference)
    reader = member("curation_respondent")
    [ reference, first, later, comedy ].each { |candidate| watch(reader, candidate) }
    Library::LibraryFilm.new(user: reader, film: film("Still to Watch")).add_to_watchlist!
    sign_in(reader)

    get community_post_path(curation)
    assert_select "section[aria-labelledby=curation-nominated-films] a[href=?]",
      edit_community_curation_endorsements_path(curation), text: I18n.t("community.curation_endorsements.endorse_films")
    get edit_community_curation_endorsements_path(curation)
    assert_response :success
    assert_select "main.ui-card.ui-narrow"
    assert_select ".ui-page-back-above", count: 0
    assert_select ".ui-actions a[href=?]", community_post_path(curation), text: I18n.t("community.curations.cancel")
    assert_select ".film-search-results > li", count: 3
    assert_select ".film-search-results > li[data-film-id=?]", reference.id.to_s
    original_activity = curation.updated_at

    travel 1.minute do
      assert_difference({ "Community::FilmEndorsement.count" => 2, "Community::Comment.count" => 2, "Community::CommentContent.count" => 2 }) do
        submit_endorsements(curation, film_ids: [ first.id, reference.id ],
          comments: { first.id => "An isolated setting.", reference.id => "The rituals fit the theme." })
      end
    end
    assert_redirected_to community_post_path(curation)
    assert_operator curation.reload.updated_at, :>, original_activity
    follow_redirect!
    assert_select ".community-nomination", count: 2 do |items|
      assert_equal [ "nomination-#{reference.id}", "nomination-#{first.id}" ], items.map { |item| item["id"] }
    end
    assert_select "#nomination-#{reference.id} .community-endorsement-badge",
      text: I18n.t("community.curations.endorsements", count: 2)
    assert_select "a[href=?]", edit_community_curation_endorsements_path(curation), text: I18n.t("community.curation_endorsements.edit_endorsements")
    get discussion_community_post_path(curation, film_id: reference.id)
    assert_select ".community-comment span.community-curation-prompt", text: "The rituals fit the theme."
    get discussion_community_post_path(curation, film_id: first.id)
    assert_select ".community-comment span.community-curation-prompt", text: "An isolated setting."

    get edit_community_curation_endorsements_path(curation)
    assert_select ".community-selected-films > li", count: 2
    assert_select ".community-selected-films > li[data-film-id=?] .community-published-comment .community-curation-prompt", first.id.to_s, text: "An isolated setting."
    submit_endorsements(curation, film_ids: [ first.id, reference.id, later.id ])
    assert_redirected_to community_post_path(curation)
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
    get edit_community_curation_endorsements_path(curation)
    assert_response :success
    assert_select ".community-selected-films > li[data-film-id=?]", reference.id.to_s

    [ [ reference.id, repeated.id, repeated.id, kept.id ], [ reference.id, reference.id, kept.id ] ].each do |submitted_ids|
      duplicate = submitted_ids.include?(repeated.id) ? repeated : reference
      assert_no_difference [ "Community::FilmEndorsement.count", "Community::Comment.count", "Community::CommentContent.count" ] do
        submit_endorsements(curation, film_ids: submitted_ids, comments: { kept.id => "Keep this." })
      end
      assert_response :unprocessable_content
      assert_select "ul.ui-errors li", text: /#{Regexp.escape(duplicate.title)}/
      assert_select ".community-selected-films > li[data-film-id=?] textarea", kept.id.to_s, text: "Keep this."
    end

    submit_endorsements(curation, film_ids: [ reference.id, kept.id ], comments: { kept.id => "Keep this." })
    assert_redirected_to community_post_path(curation)
    assert curation.film_endorsements.exists?(user: @author, film: kept)
  end

  test "a response submitted after a competing endorsement fails and preserves the other film" do
    competed = film("Night in the Pines")
    kept = film("Hidden Orchard")
    curation = publish_with
    reader = member("stale_respondent")
    [ competed, kept ].each { |candidate| watch(reader, candidate) }
    sign_in(reader)
    get edit_community_curation_endorsements_path(curation)
    assert_select ".film-search-results > li[data-film-id=?]", competed.id.to_s

    save_endorsements(curation, member: reader, film_ids: [ competed.id ])
    activity = curation.reload.updated_at
    assert_no_difference [ "Community::FilmEndorsement.count", "Community::Comment.count", "Community::CommentContent.count" ] do
      submit_endorsements(curation, film_ids: [ competed.id, kept.id ], comments: { kept.id => "Keep this too." })
    end
    assert_response :conflict
    assert_equal activity, curation.reload.updated_at
    assert_select "ul.ui-errors li", text: /saved endorsements changed/
    assert_select "a[href=?]", edit_community_curation_endorsements_path(curation), text: I18n.t("community.curation_endorsements.reload")
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
    get edit_community_curation_endorsements_path(curation)
    assert_select ".film-search-results > li[data-film-id=?]", removed.id.to_s

    Library::CollectionManagement::RemoveFromWatched.call(user_id: reader.id, library_film_id: entry.id)
    activity = curation.reload.updated_at
    assert_no_difference [ "Community::FilmEndorsement.count", "Community::Comment.count", "Community::CommentContent.count" ] do
      submit_endorsements(curation, film_ids: [ removed.id, kept.id ], comments: { removed.id => "Discard this.", kept.id => "Keep this." })
    end
    assert_response :unprocessable_content
    assert_equal activity, curation.reload.updated_at
    assert_select "ul.ui-errors li", text: /no longer eligible/
    assert_select ".community-selected-films > li[data-film-id=?]", removed.id.to_s, count: 0
    assert_select ".community-selected-films > li[data-film-id=?] textarea", kept.id.to_s, text: "Keep this."
  end

  test "a first endorsement requires a film and can include more than five" do
    curation = publish_with
    films = 6.times.map { |index| film("Watched film #{index + 1}") }
    films.each { |candidate| watch(@author, candidate) }
    sign_in(@author)
    get edit_community_curation_endorsements_path(curation)

    assert_no_difference "Community::FilmEndorsement.count" do
      submit_endorsements(curation, film_ids: [])
    end
    assert_response :unprocessable_content
    assert_select "ul.ui-errors li", text: /at least one film/

    assert_difference "Community::FilmEndorsement.count", 6 do
      submit_endorsements(curation, film_ids: films.map(&:id))
    end
    assert_redirected_to community_post_path(curation)
  end

  test "response links and requests require posting access" do
    curation = publish_with
    [ member("respond_no_conduct", accepted: false), member("respond_no_name", username: false),
      member("respond_no_avatar", avatar: false) ].each do |viewer|
      sign_in(viewer)
      get library_path
      assert_no_difference "Community::FilmEndorsement.count" do
        submit_endorsements(curation, film_ids: [ 1 ])
      end
      assert_response :forbidden
      get edit_community_curation_endorsements_path(curation)
      assert_response :forbidden
      get community_post_path(curation)
      assert_select "a[href=?]", edit_community_curation_endorsements_path(curation), count: 0
    end
  end

  test "the author can revise only the curation text after another member contributes" do
    reference = film("A Tale in the Woods")
    curation = publish_with(reference)
    reader = member("reader_before_edit")
    watch(reader, reference)
    save_endorsements(curation, member: reader, film_ids: [ reference.id ],
      comments: { reference.id => "The forest is central to the film." })
    saved_title = curation.title
    saved_description = curation.description
    activity = curation.reload.updated_at
    path = community_post_path(curation)
    sign_in(@author)

    get path
    assert_select "a[href=?]", edit_community_post_path(curation), text: I18n.t("community.curation_editing.edit_post")
    get edit_community_post_path(curation)
    assert_response :success
    assert_select "main.community-curation-form"
    assert_select ".ui-page-back-above", count: 0
    assert_select "main form .ui-actions-fixed a[href=?]", path, text: I18n.t("community.curations.cancel")
    assert_select "#curation_title[value=?]", saved_title
    assert_select "#curation_description", text: saved_description
    assert_select ".community-reference-picker", count: 0

    patch path, params: { authenticity_token: curation_action_token(path), curation: { title: " ", description: "Keep this draft." } }
    assert_response :unprocessable_content
    assert_select "ul.ui-errors li"
    assert_select "#curation_description", text: "Keep this draft."
    assert_select "main form .ui-actions-fixed a[href=?]", path, text: I18n.t("community.curations.cancel")
    curation.reload
    assert_equal [ saved_title, saved_description ], [ curation.title, curation.description ]

    travel 1.minute do
      assert_no_difference [ "Community::FilmEndorsement.count", "Community::Comment.count", "Community::CommentContent.count" ] do
        patch path, params: { authenticity_token: curation_action_token(path),
          curation: { title: "  Forest horror  ", description: "Films with an uneasy woodland setting.", community_user_id: reader.id, reference_film_ids: [] } }
      end
    end
    assert_redirected_to path
    assert_equal @author.community_user, curation.reload.community_user
    assert_equal activity, curation.updated_at
    follow_redirect!
    assert_select "h1", text: "Forest horror"
    assert_select "p.community-curation-prompt", text: "Films with an uneasy woodland setting."
    assert_select "#nomination-#{reference.id} .community-endorsement-badge", text: I18n.t("community.curations.endorsements", count: 2)
    get discussion_community_post_path(curation, film_id: reference.id)
    assert_select ".community-comment span.community-curation-prompt", text: "The forest is central to the film."
  end

  test "other members cannot edit or delete an author's curation" do
    curation = publish_with
    path = community_post_path(curation)
    sign_in(member("different_member"))

    get path
    assert_response :success
    assert_select "a[href=?]", edit_community_post_path(curation), count: 0
    assert_select "button", text: I18n.t("community.curation_deletion.delete_post"), count: 0
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]

    get edit_community_post_path(curation)
    assert_response :forbidden
    patch path, params: { authenticity_token: token, curation: { title: "Someone else's edit", description: "Unwanted changes." } }
    assert_response :forbidden
    assert_equal "Slow-burn horror", curation.reload.title

    assert_no_difference "Community::Post.count" do
      delete path, params: { authenticity_token: token }
    end
    assert_response :forbidden
  end

  test "three distinct other endorsers permanently protect a curation and invalidate open author forms" do
    reference = film("The shared reference")
    second_film = film("A second nomination")
    curation = publish_with(reference)
    path = community_post_path(curation)
    sign_in(@author)
    get edit_community_post_path(curation)
    edit_token = curation_action_token(path)
    get path
    delete_token = curation_action_token(path)

    first, second, third = %w[first_endorser second_endorser third_endorser].map { |name| member(name) }
    watch(first, second_film)
    [ first, second ].each { |reader| watch(reader, reference) }
    save_endorsements(curation, member: first, film_ids: [ reference.id, second_film.id ])
    save_endorsements(curation, member: second, film_ids: [ reference.id ])
    assert_not curation.reload.protected?

    watch(third, reference)
    save_endorsements(curation, member: third, film_ids: [ reference.id ])
    assert curation.reload.protected?
    save_endorsements(curation, member: third, film_ids: [])
    assert curation.reload.protected?

    patch path, params: { authenticity_token: edit_token, curation: { title: "Changed title", description: "Changed description" } }
    assert_response :forbidden
    delete path, params: { authenticity_token: delete_token }
    assert_response :forbidden
    assert_equal "Slow-burn horror", curation.reload.title

    get path
    assert_select "a[href=?]:not([data-turbo-frame])", edit_community_post_path(curation)
    assert_select "dialog[aria-labelledby=delete-curation-title]", count: 0
    assert_select ".community-post-tag + .community-post-tag" do
      assert_select "span:first-child", text: I18n.t("community.curation_protection.badge")
      assert_select "[role=tooltip]", text: I18n.t("community.curation_protection.badge_tooltip")
    end
  end

  test "five visible comments from at least two other members protect a curation" do
    curation, root = curation_with_comment
    first = member("first_commenter")
    second = member("second_commenter")
    Community::Discussions::PublishCurationReply.call(curation_id: curation.id, comment_id: root.id, community_user: @author.community_user, body: "An author reply.")
    4.times do |index|
      Community::Discussions::PublishCurationReply.call(curation_id: curation.id, comment_id: root.id, community_user: first.community_user, body: "Reply #{index + 1}.")
    end
    assert_not curation.reload.protected?
    removed = Community::Discussions::PublishCurationReply.call(curation_id: curation.id, comment_id: root.id, community_user: first.community_user,
      body: "Fifth reply from the same reader.").fetch(:reply).comment
    assert_not curation.reload.protected?
    Community::Discussions::ManageCurationComment.delete(curation_id: curation.id, comment_id: removed.id, community_user: first.community_user)
    Community::Discussions::PublishCurationReply.call(curation_id: curation.id, comment_id: root.id, community_user: second.community_user, body: "Fifth visible reply.")
    assert curation.reload.protected?
  end

  test "the single additional description is editable only by the protected post's author and survives disassociation" do
    curation, root = curation_with_comment
    reference = root.film_endorsement.film
    update_path = community_curation_additional_description_path(curation)
    disassociate_path = community_curation_disassociate_path(curation)

    sign_in(@author)
    get community_post_path(curation)
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
    patch update_path, params: { authenticity_token: token, curation: { additional_description: "Before protection." } }
    assert_response :forbidden
    protect_with_endorsements(curation, reference)

    sign_in(member("other_update_reader"))
    get community_post_path(curation)
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
    patch update_path, params: { authenticity_token: token, curation: { additional_description: "Unauthorized update." } }
    assert_response :forbidden
    patch disassociate_path, params: { authenticity_token: token }
    assert_response :forbidden

    sign_in(@author)
    get edit_community_post_path(curation)
    assert_select "main.community-curation-form form .ui-actions-fixed a[href=?]", community_post_path(curation),
      text: I18n.t("community.curations.cancel")
    assert_select "dl dt", text: "Protected title"
    assert_select "dl dt", text: "Protected description"
    assert_select "dl dd span", text: curation.title
    assert_select "dl dd span", text: curation.description
    assert_select "input[name^=curation], textarea[name^=curation]:not(#curation_additional_description)", count: 0
    update_token = curation_action_token(update_path)
    patch update_path, params: { authenticity_token: update_token,
      curation: { additional_description: "x" * (Community::PostCommunityCuration::DESCRIPTION_LIMIT + 1) } }
    assert_response :unprocessable_content
    assert_nil curation.reload.additional_description
    [ "First description.", "Revised description." ].each do |description|
      get edit_community_post_path(curation)
      update_token = curation_action_token(update_path)
      patch update_path, params: { authenticity_token: update_token, curation: { additional_description: description } }
      assert_redirected_to community_post_path(curation)
    end
    follow_redirect!
    assert_select "p.community-curation-prompt", text: "Set in small communities."
    assert_select ".community-curation-author", text: @author.community_user&.community_username
    assert_select "p.community-curation-prompt + section[aria-labelledby=curation-additional-description]", count: 1 do
      assert_select "h2", text: "EDIT:"
      assert_select "p", text: "Revised description."
    end
    assert_select "p.community-curation-prompt", text: "First description.", count: 0
    get edit_community_post_path(curation)
    assert_select "#curation_additional_description", text: "Revised description."
    update_token = curation_action_token(update_path)
    patch update_path, params: { authenticity_token: update_token, curation: { additional_description: " " } }
    assert_redirected_to community_post_path(curation)
    follow_redirect!
    assert_select "section[aria-labelledby=curation-additional-description]", count: 0
    assert_nil curation.reload.additional_description
    get edit_community_post_path(curation)
    update_token = curation_action_token(update_path)
    patch update_path, params: { authenticity_token: update_token, curation: { additional_description: "Description that stays." } }
    assert_redirected_to community_post_path(curation)
    follow_redirect!
    patch disassociate_path, params: { authenticity_token: curation_action_token(disassociate_path) }
    assert_redirected_to community_post_path(curation)
    assert_nil curation.reload.community_user
    assert curation.film_endorsements.active.exists?(user: @author, film: reference)
    assert_equal "A quiet setting.", root.reload.content.body
    follow_redirect!
    assert_select "section[aria-labelledby=curation-additional-description] p", text: "Description that stays."
    assert_select ".community-curation-author", count: 0
    assert_select "a[href=?]", edit_community_post_path(curation), count: 0
    patch update_path, params: { authenticity_token: update_token, curation: { additional_description: "Stale description." } }
    assert_response :forbidden
    get community_path
    assert_select "footer .community-curation-card-author", text: I18n.t("community.curation_protection.unattributed") do
      assert_select "img", count: 0
    end
    assert_select ".community-post-tag + .community-post-tag", text: I18n.t("community.curation_protection.badge")
    assert_select ".community-post-tags [role=tooltip]", count: 0
  end

  test "an author can delete a curation and its contributions without changing Library or Registry" do
    reference = film("The Hollow Oak")
    curation = publish_with(reference)
    reader = member("reader_before_deletion")
    watched_entry = watch(reader, reference)
    save_endorsements(curation, member: reader, film_ids: [ reference.id ],
      comments: { reference.id => "The oak anchors the story." })
    root = curation.comments.sole
    reply = Community::Discussions::PublishCurationReply.call(curation_id: curation.id, comment_id: root.id, community_user: @author.community_user,
      body: "It anchors the setting too.").fetch(:reply).comment
    Community::Discussions::PublishCurationReply.call(curation_id: curation.id, comment_id: reply.id, community_user: reader.community_user,
      body: "I agree about the setting.")
    path = community_post_path(curation)
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

    get new_reply_community_post_comment_path(curation, root)
    assert_response :success
    path = reply_community_post_comment_path(curation, root)
    body = "x" * Community::CommentContent::BODY_LIMIT
    travel 1.minute do
      assert_difference({ "Community::Comment.count" => 1, "Community::CommentContent.count" => 1,
                          "Community::FilmEndorsement.count" => 0 }) do
        post path, params: { authenticity_token: curation_action_token(path), body: }
      end
    end

    reply = curation.comments.find_by!(parent_id: root.id)
    assert_equal root.id, reply.root_id
    assert_equal member.community_user, reply.content.community_user
    assert_equal body, reply.content.body
    assert_operator curation.reload.updated_at, :>, activity
    assert_redirected_to community_post_path(curation, reply: reply.id, anchor: "comment-#{reply.id}")
    follow_redirect!
    assert_select "#nomination-#{reference.id} .community-endorsement-badge", text: I18n.t("community.curations.endorsements", count: 1)
    assert_select "#nomination-#{reference.id} details.community-film-comments[open] > summary", text: I18n.t("community.curations.comments", count: 2)
    assert_select "#replies-#{root.id}[open] > .community-comment-thread > #comment-#{reply.id}", text: /#{body}/

    get community_path
    assert_select ".community-curation-card-counts li", text: I18n.t("community.curations.comments", count: 2)
  end

  test "discussion reads keep comment records and markup bounded as branches grow" do
    films = [ film("The quiet village"), film("An unrelated forest") ]
    films.each { |candidate| watch(@author, candidate) }
    curation = Community::Curations::PublishCuration.call(community_user: @author.community_user, title: "Folk horror", description: "Quiet settings.",
      reference_film_ids: films.map(&:id), reference_comments: { films.first.id => "The village.", films.last.id => "The forest." })
    root, unrelated_root = curation.comments.order(:id).to_a
    reader = member("discussion_reader")
    sign_in(reader)
    path = community_post_path(curation)
    assert_equal 0, loaded_discussion_records { get path }
    initial_size = response.body.bytesize

    22.times do |index|
      Community::Discussions::PublishCurationReply.call(curation_id: curation.id, comment_id: root.id, community_user: reader.community_user, body: "Village reply #{index + 1}.")
      Community::Discussions::PublishCurationReply.call(curation_id: curation.id, comment_id: unrelated_root.id, community_user: reader.community_user, body: "Forest reply #{index + 1}.")
    end

    assert_equal 0, loaded_discussion_records { get path }
    assert_operator response.body.bytesize, :<, initial_size + 100
    assert_select "article.community-comment", count: 0
    assert_select "#film-comment-count-#{films.first.id}", text: I18n.t("community.curations.comments", count: 23)

    branch = discussion_community_post_path(curation, film_id: films.first.id, parent_id: root.id)
    assert_operator loaded_discussion_records { get branch }, :<=, 44
    assert_response :success
    assert_select "article.community-comment", count: 20
    refute_includes response.body, "Village reply 21."
    refute_includes response.body, "Forest reply"
    next_page = Nokogiri::HTML(response.body).at_css(".community-comment-loader")["data-discussion-url"]
    get next_page
    assert_select "article.community-comment", count: 2
    assert_select "article.community-comment", text: /Village reply 22\./

    selected = curation.comments.where(parent_id: root.id).last
    assert_equal "/community/posts/#{curation.id}", community_post_path(curation)
    get "/community/community-curations/#{curation.id}"
    assert_response :not_found
    get community_post_path(curation), params: { reply: selected.id }
    assert_response :success
    assert_select "#comment-#{selected.id}", text: /Village reply 22\./
    refute_includes response.body, "Forest reply"

    reply_path = reply_community_post_comment_path(curation, root)
    get new_reply_community_post_comment_path(curation, root)
    token = curation_action_token(reply_path)
    records = loaded_discussion_records do
      post reply_path, params: { authenticity_token: token, body: "The newest reply." },
        headers: { "Turbo-Frame" => "comment-composer-#{root.id}" }
    end
    assert_operator records, :<=, 4
    assert_select "turbo-stream[action=append][target=?] article.community-comment", "replies-#{root.id}", count: 1
    assert_select "turbo-stream[target=?]", "film-comment-count-#{films.first.id}", text: I18n.t("community.curations.comments", count: 24)
    refute_includes response.body, "Village reply"
    refute_includes response.body, "Forest reply"
  end

  test "reply submissions reject oversized or blank text without saving comment structure" do
    curation, root = curation_with_comment
    sign_in(member("reply_validator"))
    path = reply_community_post_comment_path(curation, root)
    get new_reply_community_post_comment_path(curation, root)
    activity = curation.updated_at

    oversized_body = "x" * (Community::CommentContent::BODY_LIMIT + 1)
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
    get discussion_community_post_path(curation, film_id: Community::Discussions::CurationDiscussion.film_id_for(root))
    assert_response :success
    assert_select "#comment-#{root.id}"
    assert_select "a[href=?]", new_reply_community_post_comment_path(curation, root), count: 0
    get community_post_path(curation)
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]

    get new_reply_community_post_comment_path(curation, root)
    assert_response :forbidden
    assert_no_difference [ "Community::Comment.count", "Community::CommentContent.count" ] do
      post reply_community_post_comment_path(curation, root), params: { authenticity_token: token, body: "An unauthorized reply." }
    end
    assert_response :forbidden
  end

  test "a reply target from another curation cannot be used in a direct request" do
    curation, root = curation_with_comment
    other = publish_with
    sign_in(member("reply_other_curation"))
    get new_reply_community_post_comment_path(curation, root)
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]

    get new_reply_community_post_comment_path(other, root)
    assert_response :not_found
    assert_no_difference [ "Community::Comment.count", "Community::CommentContent.count" ] do
      post reply_community_post_comment_path(other, root), params: { authenticity_token: token, body: "A mismatched reply." }
    end
    assert_response :not_found
  end

  test "a reply submitted after its curation was deleted fails without recreating anything" do
    curation, root = curation_with_comment
    sign_in(member("reply_stale_target"))
    get new_reply_community_post_comment_path(curation, root)
    path = reply_community_post_comment_path(curation, root)
    token = curation_action_token(path)

    Community::Curations::DeleteCuration.call(curation_id: curation.id, community_user: @author.community_user)
    assert_no_difference [ "Community::Post.count", "Community::Comment.count", "Community::CommentContent.count" ] do
      post path, params: { authenticity_token: token, body: "A stale reply." }
    end
    assert_response :not_found
  end

  test "curation publication and endorsement updates reject oversized opening comments atomically" do
    reference = film("A film for opening comments")
    watch(@author, reference)
    sign_in(@author)
    oversized = "x" * 4_001

    get new_community_post_path
    assert_no_difference [ "Community::Post.count", "Community::FilmEndorsement.count", "Community::CommentContent.count" ] do
      submit_curation(reference_film_ids: [ reference.id ], reference_comments: { reference.id.to_s => oversized })
    end
    assert_response :unprocessable_content
    assert_select "textarea[maxlength='4000']", text: oversized
    assert_select ".ui-errors li", text: /4000/

    submit_curation(reference_film_ids: [ reference.id ])
    assert_response :see_other
    curation = Community::PostCommunityCuration.sole
    reader = member("opening_comment_reader")
    watch(reader, reference)
    sign_in(reader)
    get edit_community_curation_endorsements_path(curation)
    assert_no_difference [ "Community::FilmEndorsement.count", "Community::CommentContent.count" ] do
      submit_endorsements(curation, film_ids: [ reference.id ], comments: { reference.id.to_s => oversized })
    end
    assert_response :unprocessable_content
    assert_select "textarea[maxlength='4000']", text: oversized
    get edit_community_curation_endorsements_path(curation)
    submit_endorsements(curation, film_ids: [ reference.id ], comments: { reference.id.to_s => "x" * 4_000 })
    assert_response :see_other
    assert_equal 4_000, curation.comments.sole.content.body.length
  end

  test "legacy stored opening comments stay visible and can be edited down to the limit" do
    curation, root = curation_with_comment
    legacy_body = "x" * 4_001
    # Simulate text already persisted before opening comments had a limit.
    Community::CommentContent.where(id: root.content.id).update_all(body: legacy_body)
    sign_in(@author)
    get community_post_path(curation, reply: root.id)
    assert_select "#comment-#{root.id} .community-curation-prompt", text: legacy_body

    path = community_post_comment_path(curation, root)
    get edit_community_post_comment_path(curation, root)
    assert_select "textarea[name=body][maxlength='4000']", text: legacy_body
    patch path, params: { authenticity_token: curation_action_token(path), body: legacy_body }
    assert_response :see_other
    assert_equal legacy_body, root.content.reload.body
    assert_nil root.content.edited_at

    get edit_community_post_comment_path(curation, root)
    shortened_body = "x" * 4_000
    patch path, params: { authenticity_token: curation_action_token(path), body: shortened_body }
    assert_response :see_other
    assert_equal shortened_body, root.content.reload.body
    assert root.content.edited_at.present?
  end

  test "authors can edit an opening comment and reply without changing board activity" do
    curation, root = curation_with_comment
    reply = Community::Discussions::PublishCurationReply.call(curation_id: curation.id, comment_id: root.id, community_user: @author.community_user,
      body: "My original reply.").fetch(:reply).comment
    activity = curation.reload.updated_at
    sign_in(@author)
    limit = Community::CommentContent::BODY_LIMIT
    long_body = "a" * (limit + 1)
    max_body = "a" * limit

    get edit_community_post_comment_path(curation, root)
    root_path = community_post_comment_path(curation, root)
    assert_select "textarea[name=body][maxlength=?]", limit.to_s, text: root.content.body
    patch root_path, params: { authenticity_token: curation_action_token(root_path), body: "  #{root.content.body} " }
    assert_response :see_other
    assert_nil root.content.reload.edited_at

    get edit_community_post_comment_path(curation, root)
    patch root_path, params: { authenticity_token: curation_action_token(root_path), body: long_body }
    assert_response :unprocessable_content
    assert_equal "A quiet setting.", root.content.reload.body
    assert_nil root.content.edited_at

    get edit_community_post_comment_path(curation, root)
    travel 1.minute do
      patch root_path, params: { authenticity_token: curation_action_token(root_path), body: max_body }
    end
    assert_redirected_to community_post_path(curation, reply: root.id, anchor: "comment-#{root.id}")
    assert_equal max_body, root.content.reload.body
    edited_at = root.content.edited_at
    assert edited_at.present?
    get edit_community_post_comment_path(curation, root)
    travel 2.minutes do
      patch root_path, params: { authenticity_token: curation_action_token(root_path), body: max_body }
    end
    assert_equal edited_at, root.content.reload.edited_at

    get edit_community_post_comment_path(curation, reply)
    reply_path = community_post_comment_path(curation, reply)
    assert_select "textarea[name=body][maxlength=?]", limit.to_s, text: "My original reply."
    patch reply_path, params: { authenticity_token: curation_action_token(reply_path), body: long_body }
    assert_response :unprocessable_content
    assert_select ".ui-errors li"
    assert_select "textarea[name=body]", text: long_body
    assert_equal "My original reply.", reply.content.reload.body

    travel 1.minute do
      patch reply_path, params: { authenticity_token: curation_action_token(reply_path), body: "My updated reply." }
    end
    assert_redirected_to community_post_path(curation, reply: reply.id, anchor: "comment-#{reply.id}")
    assert_equal "My updated reply.", reply.content.reload.body
    assert reply.content.edited_at.present?
    assert_equal root.id, reply.reload.parent_id
    assert_equal activity, curation.reload.updated_at
  end

  test "other members cannot edit or delete an authored comment" do
    curation, root = curation_with_comment
    path = community_post_comment_path(curation, root)
    sign_in(member("other_comment_author"))
    get community_post_path(curation)
    assert_select "a[href=?]", edit_community_post_comment_path(curation, root), count: 0
    assert_select "form[action=?]", path, count: 0
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]

    get edit_community_post_comment_path(curation, root)
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
    get new_reply_community_post_comment_path(curation, root)
    reply_path = reply_community_post_comment_path(curation, root)
    reply_token = curation_action_token(reply_path)
    reply_cookie = cookies[:session_id]

    sign_in(@author)
    get community_post_path(curation, reply: root.id)
    delete_path = community_post_comment_path(curation, root)
    activity = curation.updated_at
    travel 1.minute do
      assert_difference({ "Community::Comment.count" => -1, "Community::CommentContent.count" => -1,
                          "Community::FilmEndorsement.count" => 0 }) do
        delete delete_path, params: { authenticity_token: curation_action_token(delete_path) }
      end
    end
    assert_redirected_to community_post_path(curation, anchor: "nomination-#{root.film_endorsement.film_id}")
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
    get community_post_path(curation, reply: root.id)
    path = community_post_comment_path(curation, root)
    token = curation_action_token(path)
    reply = Community::Discussions::PublishCurationReply.call(curation_id: curation.id, comment_id: root.id, community_user: reader.community_user,
      body: "The mood also helps.").fetch(:reply).comment
    activity = curation.reload.updated_at

    travel 1.minute do
      assert_difference({ "Community::Comment.count" => 0, "Community::CommentContent.count" => -1,
                          "Community::FilmEndorsement.count" => 0 }) do
        delete path, params: { authenticity_token: token }
      end
    end
    assert_redirected_to community_post_path(curation, reply: root.id, anchor: "comment-#{root.id}")
    assert_nil root.reload.content
    assert_equal root.id, reply.reload.parent_id
    assert_equal activity, curation.reload.updated_at
    follow_redirect!
    assert_select "#comment-#{root.id}", text: I18n.t("community.curation_replies.removed")
    assert_select "#comment-#{root.id} a, #comment-#{root.id} strong", count: 0
    assert_select "#replies-#{root.id}[open] #comment-#{reply.id}", text: /The mood also helps/
    assert_select "#film-comment-count-#{root.film_endorsement.film_id}", text: I18n.t("community.curations.comments", count: 1)
    marker_token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]

    get new_reply_community_post_comment_path(curation, root)
    assert_response :not_found
    assert_no_difference [ "Community::Comment.count", "Community::CommentContent.count" ] do
      post reply_community_post_comment_path(curation, root), params: { authenticity_token: marker_token, body: "A reply to the marker." }
    end
    assert_response :not_found
    get new_reply_community_post_comment_path(curation, reply)
    assert_response :success

    get community_path
    assert_select ".community-curation-card-counts li", text: I18n.t("community.curations.comments", count: 1)
  end

  test "opening comments can be added later and published comments cannot be edited in the endorsements form" do
    nominated_film = film("The Quiet Field")
    curation = publish_with(nominated_film)
    sign_in(@author)
    get edit_community_curation_endorsements_path(curation)
    original_activity = curation.updated_at

    travel 1.minute do
      assert_difference "Community::CommentContent.count", 1 do
        submit_endorsements(curation, film_ids: [ nominated_film.id ], comments: { nominated_film.id => "The landscape fits." })
      end
    end
    assert_redirected_to community_post_path(curation)
    assert_operator curation.reload.updated_at, :>, original_activity
    root = curation.comments.sole

    get edit_community_curation_endorsements_path(curation)
    assert_select ".community-selected-films .community-published-comment .community-curation-prompt", text: "The landscape fits."
    submit_endorsements(curation, film_ids: [ nominated_film.id ], comments: { nominated_film.id => "Attempted overwrite." })
    assert_response :unprocessable_content
    assert_select ".ui-errors li", text: /Edit the published comment/
    assert_equal "The landscape fits.", root.content.reload.body

    get community_post_path(curation, reply: root.id)
    delete_path = community_post_comment_path(curation, root)
    delete delete_path, params: { authenticity_token: curation_action_token(delete_path) }
    assert_not Community::Comment.exists?(root.id)
    assert curation.film_endorsements.active.exists?(film: nominated_film, user: @author)
    get edit_community_curation_endorsements_path(curation)
    submit_endorsements(curation, film_ids: [ nominated_film.id ], comments: { nominated_film.id => "A fresh opening comment." })
    assert_redirected_to community_post_path(curation)
    assert_equal "A fresh opening comment.", curation.comments.sole.content.body
  end

  test "an inline edit invalidates an open endorsement editor without losing eligible draft comments" do
    curation, root = curation_with_comment
    film_id = Community::Discussions::CurationDiscussion.film_id_for(root)
    candidate = film("A new reference")
    watch(@author, candidate)
    sign_in(@author)
    get edit_community_curation_endorsements_path(curation)
    stale_submission = endorsement_submission(curation, film_ids: [ film_id, candidate.id ], comments: { candidate.id => "A draft to keep." })
    get edit_community_post_comment_path(curation, root)
    comment_path = community_post_comment_path(curation, root)
    patch comment_path, params: { authenticity_token: curation_action_token(comment_path), body: "A newer opening." }
    assert_response :see_other

    patch community_curation_endorsements_path(curation), params: stale_submission
    assert_response :conflict
    assert_select ".community-selected-films .community-published-comment .community-curation-prompt", text: "A newer opening."
    assert_select ".community-selected-films textarea", text: "A draft to keep."
    assert_equal "A newer opening.", root.content.reload.body
  end

  test "a new opening on the same endorsement preserves a deleted root and its replies" do
    curation, original = curation_with_comment
    endorsement = original.film_endorsement
    reader = member("surviving_replier")
    reply = Community::Discussions::PublishCurationReply.call(curation_id: curation.id, comment_id: original.id, community_user: reader.community_user,
      body: "The original discussion.").fetch(:reply).comment
    sign_in(@author)
    get community_post_path(curation, reply: original.id)
    delete_path = community_post_comment_path(curation, original)
    delete delete_path, params: { authenticity_token: curation_action_token(delete_path) }
    assert_response :see_other
    get edit_community_curation_endorsements_path(curation)
    film_id = endorsement.film_id
    submit_endorsements(curation, film_ids: [ film_id ], comments: { film_id => "A new opening." })
    assert_response :see_other
    fresh_root = endorsement.comments.joins(:content).sole
    assert_not_equal original.id, fresh_root.id
    assert_equal original.id, reply.reload.parent_id

    get edit_community_post_comment_path(curation, fresh_root)
    comment_path = community_post_comment_path(curation, fresh_root)
    patch comment_path, params: { authenticity_token: curation_action_token(comment_path), body: "A revised opening." }
    assert_response :see_other
    assert_equal fresh_root.id, endorsement.comments.joins(:content).sole.id
    assert_equal "A revised opening.", fresh_root.content.reload.body
  end

  test "a saved editor snapshot cannot be submitted by another member or on another curation" do
    curation, root = curation_with_comment
    other_curation = publish_with
    sign_in(@author)
    get edit_community_curation_endorsements_path(curation)
    submission = endorsement_submission(curation, film_ids: [])
    get edit_community_curation_endorsements_path(other_curation)
    patch community_curation_endorsements_path(other_curation),
      params: submission.merge(authenticity_token: curation_action_token(community_curation_endorsements_path(other_curation)))
    assert_response :conflict

    sign_in(member("other_editor"))
    get edit_community_curation_endorsements_path(curation)
    path = community_curation_endorsements_path(curation)
    patch path, params: submission.merge(authenticity_token: curation_action_token(path))
    assert_response :conflict
    assert_equal "A quiet setting.", root.content.reload.body
    assert_equal [ @author.id ], curation.film_endorsements.active.pluck(:user_id)
  end

  test "an endorser who loses posting access cannot save an open editor" do
    curation, root = curation_with_comment
    sign_in(@author)
    get edit_community_curation_endorsements_path(curation)
    submission = endorsement_submission(curation, film_ids: [])
    @author.record_community_code_of_conduct_acceptance!(version: "previous")

    patch community_curation_endorsements_path(curation), params: submission
    assert_response :forbidden
    assert_equal "A quiet setting.", root.content.reload.body
  end

  test "withdrawal leaves a zero-endorsement film and reply thread until re-endorsement starts a fresh root" do
    curation, original = curation_with_comment
    nominated_film = original.film_endorsement.film
    reader = member("old_root_reader")
    sign_in(@author)
    get edit_community_curation_endorsements_path(curation)
    reply = Community::Discussions::PublishCurationReply.call(curation_id: curation.id, comment_id: original.id, community_user: reader.community_user,
      body: "A surviving reply.").fetch(:reply).comment
    activity = curation.reload.updated_at
    submit_endorsements(curation, film_ids: [])
    assert_redirected_to community_post_path(curation)
    assert_equal activity, curation.reload.updated_at
    assert_empty curation.film_endorsements.active
    assert_nil original.reload.content
    follow_redirect!
    assert_select "#nomination-#{nominated_film.id} .community-endorsement-badge", text: I18n.t("community.curations.endorsements", count: 0)
    get community_post_path(curation, reply: reply.id)
    assert_select "#nomination-#{nominated_film.id} #comment-#{original.id}", text: I18n.t("community.curation_replies.removed")
    assert_select "#comment-#{original.id} a", count: 0
    assert_select "#comment-#{reply.id} a[href=?]", new_reply_community_post_comment_path(curation, reply)
    get new_reply_community_post_comment_path(curation, original)
    assert_response :not_found
    get new_reply_community_post_comment_path(curation, reply)
    assert_response :success
    reply_path = reply_community_post_comment_path(curation, reply)
    post reply_path, params: { authenticity_token: curation_action_token(reply_path), body: "The discussion continues." }
    assert_response :see_other
    mention = curation.comments.find_by!(parent: reply)

    get community_path(q: nominated_film.title)
    assert_select "a.community-curation-card[href=?]", community_post_path(curation)
    assert_select ".community-curation-card-counts li", text: I18n.t("community.curations.endorsements", count: 0)
    get edit_community_curation_endorsements_path(curation)
    submit_endorsements(curation, film_ids: [ nominated_film.id ], comments: { nominated_film.id => "A fresh opening comment." })
    assert_redirected_to community_post_path(curation)
    fresh_endorsement = curation.film_endorsements.active.sole
    fresh_root = fresh_endorsement.comments.sole
    assert_not_equal original.film_endorsement_id, fresh_endorsement.id
    assert_equal "A fresh opening comment.", fresh_root.content.body
    assert_nil fresh_root.parent_id
    assert_equal original.id, reply.reload.parent_id
    assert_equal original.id, mention.reload.root_id
    get community_post_path(curation, reply: fresh_root.id)
    assert_select "#nomination-#{nominated_film.id} #comment-#{fresh_root.id}", text: /A fresh opening comment/
  end

  test "an unwatched saved film can be edited and withdrawn and its leaf comment is removed" do
    curation, root = curation_with_comment
    nominated_film = root.film_endorsement.film
    entry = Library::LibraryFilm.find_by!(user: @author, film: nominated_film)
    Library::CollectionManagement::RemoveFromWatched.call(user_id: @author.id, library_film_id: entry.id)
    sign_in(@author)
    get edit_community_curation_endorsements_path(curation)
    assert_select ".film-search-results > li", count: 0
    assert_select ".community-selected-films .community-published-comment .community-curation-prompt", text: root.content.body
    get edit_community_post_comment_path(curation, root)
    comment_path = community_post_comment_path(curation, root)
    patch comment_path, params: { authenticity_token: curation_action_token(comment_path), body: "Still fits." }
    assert_response :see_other
    assert_equal "Still fits.", root.content.reload.body

    get edit_community_curation_endorsements_path(curation)
    submit_endorsements(curation, film_ids: [])
    assert_redirected_to community_post_path(curation)
    assert_not Community::Comment.exists?(root.id)
    assert_not curation.film_endorsements.exists?
    follow_redirect!
    assert_select "#nomination-#{nominated_film.id}", count: 0
  end

  test "removing the last surviving reply takes a zero-endorsement film off the post and board search" do
    curation, original = curation_with_comment
    nominated_film = original.film_endorsement.film
    reader = member("surviving_reply_author")
    reply = Community::Discussions::PublishCurationReply.call(curation_id: curation.id, comment_id: original.id, community_user: reader.community_user,
      body: "A surviving reply.").fetch(:reply).comment
    sign_in(@author)
    get edit_community_curation_endorsements_path(curation)
    submit_endorsements(curation, film_ids: [])
    assert_redirected_to community_post_path(curation)
    sign_in(reader)
    get community_post_path(curation, reply: reply.id)
    assert_select "#comment-#{reply.id}"
    delete_path = community_post_comment_path(curation, reply)
    delete delete_path, params: { authenticity_token: curation_action_token(delete_path) },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_redirected_to community_post_path(curation)
    follow_redirect!
    assert_select "#nomination-#{nominated_film.id}", count: 0
    get community_path(q: nominated_film.title)
    assert_select "a.community-curation-card", count: 0
  end

  private

  def assert_library_events(user, film, *names)
    stream = DomainEvents::DomainEventStream.find_by!(user:, publisher: Library::Events::PUBLISHING_DOMAIN, stream_key: "film:#{film.id}")
    expected = names.map { |name| [ name, { "user_id" => user.id, "film_id" => film.id } ] }
    assert_equal expected, stream.domain_events.order(:sequence).pluck(:name, :payload)
  end

  def loaded_discussion_records
    count = 0
    receiver = ->(*args) do
      payload = args.last
      count += payload.fetch(:record_count) if %w[Community::Comment Community::CommentContent].include?(payload[:class_name])
    end
    ActiveSupport::Notifications.subscribed(receiver, "instantiation.active_record") { yield }
    count
  end

  def curation_with_comment
    reference = film("A film with a discussion")
    watch(@author, reference)
    curation = Community::Curations::PublishCuration.call(community_user: @author.community_user, title: "Films with a quiet setting",
      description: "Set in small communities.", reference_film_ids: [ reference.id ], reference_comments: { reference.id => "A quiet setting." })
    [ curation, curation.comments.sole ]
  end

  def member(name, accepted: true, username: true, avatar: true)
    create_community_account(email_address: "#{name}@example.test", password: PASSWORD,
      password_confirmation: PASSWORD, email_confirmed_at: Time.current,
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
    Community::Curations::PublishCuration.call(community_user: @author.community_user, title: "Slow-burn horror", description: "Films for this theme.",
      reference_film_ids: films.map(&:id), reference_comments: {})
  end

  def submit_curation(**fields)
    page = Nokogiri::HTML(response.body)
    token = page.at_css("form[action='#{community_posts_path}'] input[name=authenticity_token]")&.[]("value")
    token ||= page.at_css('meta[name="csrf-token"]')["content"]
    curation = { title: "Slow-burn modern folk horror", description: "Stories that take their time." }.merge(fields)
    post community_posts_path, params: { authenticity_token: token, post_type: "community_curation", curation: }
  end

  def endorsement_submission(curation, film_ids:, comments: {})
    path = community_curation_endorsements_path(curation)
    page = Nokogiri::HTML(response.body)
    form = page.at_css("form[action='#{path}']")
    token = form&.at_css("input[name=authenticity_token]")&.[]("value")
    token ||= page.at_css('meta[name="csrf-token"]')["content"]
    snapshot = form&.at_css('input[name="endorsements[snapshot]"]')&.[]("value")
    fields = { film_ids: film_ids.presence, comments: comments.presence, snapshot: }.compact
    { authenticity_token: token, endorsements: fields }
  end

  def submit_endorsements(curation, film_ids:, comments: {})
    patch community_curation_endorsements_path(curation), params: endorsement_submission(curation, film_ids:, comments:)
  end

  def save_endorsements(curation, member:, film_ids:, comments: {})
    snapshot = Community::Curations::EditCurationEndorsements.load_for_edit(curation_id: curation.id, community_user: member.community_user).fetch(:snapshot)
    result = Community::Curations::EditCurationEndorsements.call(curation_id: curation.id, community_user: member.community_user, film_ids:, comments:, snapshot:)
    assert_empty result.fetch(:curation).errors
  end

  def protect_with_endorsements(curation, reference)
    %w[first_protecting_member second_protecting_member third_protecting_member].map do |name|
      reader = member(name)
      watch(reader, reference)
      save_endorsements(curation, member: reader, film_ids: [ reference.id ])
      reader
    end
  end

  def curation_action_token(path)
    Nokogiri::HTML(response.body).at_css("form[action='#{path}'] input[name=authenticity_token]")["value"]
  end
end
