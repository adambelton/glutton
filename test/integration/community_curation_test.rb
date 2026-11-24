require "test_helper"

class CommunityCurationTest < ActionDispatch::IntegrationTest
  PASSWORD = "a long test password"

  setup do
    controllers = [ Community::CurationsController, Community::BoardController, LibraryController ]
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
    assert_select "a[href=?]", new_community_curation_path, text: I18n.t("community.curations.create")
    get new_community_curation_path
    assert_response :success
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
    assert_select ".community-curation-prompt", "Stories that take their time."
    assert_select ".community-post-tag", text: I18n.t("community.curations.tag"), count: 1
    assert_select "h2", I18n.t("community.curations.nominated_films")
    assert_select "ol.community-nominations > li" do |rows|
      assert_equal [ second.title, first.title ], rows.map { |row| row.at_css("h3").text }
    end
    assert_select "p", text: I18n.t("community.curations.endorsement_order")
    assert_select ".community-endorsement-badge", text: I18n.t("community.curations.endorsements", count: 1), count: 2
    assert_select "#nomination-#{first.id} details:not([open])" do
      assert_select "summary", text: I18n.t("community.curations.comments", count: 1)
      assert_select "article p", text: "The sense of dread builds slowly."
      assert_select "article strong", text: @author.community_username
      assert_select "article button[disabled]", count: 2
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
    assert_select "nav.community-board-pagination", text: /Page 1 of 2/
    assert_select "nav a[rel=next][href=?]", community_path(page: 2)
    assert_select "nav a[rel=prev]", count: 0

    get community_path(page: 2)
    assert_response :success
    assert_select ".community-curation-card h2", count: 2 do |titles|
      assert_equal [ "Curation 2", "Curation 1" ], titles.map(&:text)
    end
    assert_select "nav.community-board-pagination", text: /Page 2 of 2/
    assert_select "nav a[rel=prev][href=?]", community_path
    assert_select "nav a[rel=next]", count: 0

    get community_path(page: 3)
    assert_redirected_to community_path(page: 2)
    get community_path(page: "invalid")
    assert_redirected_to community_path
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

  private

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
end
