require "test_helper"

class CommunityFilmDebriefTest < ActionDispatch::IntegrationTest
  PASSWORD = "a long test password"

  setup do
    controllers = [ Community::PostsController, Community::PostCommentsController, Community::BoardController, LibraryController ]
    @previous_forgery_protection = controllers.index_with(&:allow_forgery_protection)
    controllers.each { |controller| controller.allow_forgery_protection = true }
    @member = member("debrief_reader")
  end

  teardown do
    @previous_forgery_protection.each { |controller, enabled| controller.allow_forgery_protection = enabled }
  end

  test "a Watched-film placeholder opens one system-owned thread which survives account closure" do
    film = Registry::Film.create!(id: 1_000_000_000, title: "The Quiet House", release_date: Date.new(1987, 4, 1),
      tmdb_metadata: { details: { poster_path: "/quiet-house.jpg" } })
    watch(@member, film)
    sign_in(@member)
    path = community_posts_path

    assert_no_difference "Community::Post.count" do
      get community_post_path(film.id)
      assert_response :not_found
      get community_path
      assert_select ".community-film-debrief-card", count: 0
      get community_path(q: "quiet")
      assert_select "article.community-film-debrief-card h2", text: "#{film.title} (1987)"
    end
    publication = debrief_publication_fields(path)
    assert_difference "Community::PostFilmDebrief.count", 1 do
      assert_no_difference "Community::Comment.count" do
        post path, params: publication
      end
    end
    debrief = Community::PostFilmDebrief.find_by!(film:)
    refute_equal film.id, debrief.id
    assert_response :see_other
    assert_redirected_to community_post_path(debrief)
    follow_redirect!
    assert_select "h1", text: "#{film.title} (1987)" do
      assert_select ".film-year", text: "(1987)"
    end
    assert_select ".community-post-tag[tabindex='0'] [role=tooltip]", text: I18n.t("community.film_debriefs.badge_tooltip")
    assert_select ".community-post-heading h1 + .community-post-tags + .community-film-debrief-author .community-glutton-avatar + strong",
      text: I18n.t("ui.wordmark")
    assert_select ".community-debrief-description p", text: I18n.t("community.film_debriefs.introduction", title: film.title)
    assert_select ".community-debrief-poster img.film-poster[src=?]", "https://image.tmdb.org/t/p/w500/quiet-house.jpg"
    get "/community/film-debriefs/#{film.id}"
    assert_response :not_found

    assert_nil debrief.community_user_id
    assert_nil debrief.deletable_community_user_id
    assert_no_changes -> { debrief.reload.updated_at } do
      assert_no_difference "Community::PostFilmDebrief.count" do
        post path, params: publication
      end
    end
    assert_redirected_to community_post_path(debrief)

    client = Aws::S3::Client.new(region: "auto", stub_responses: true)
    log = Identity::AccountAdministration::DeletionLog.new(client:, bucket: "fixture", namespace: "recovery")
    Identity::AccountAdministration::ManageRegisteredAccount.new(user_id: @member.id).close_account(deletion_log: log)
    assert Community::PostFilmDebrief.exists?(debrief.id)
  end

  test "a stale placeholder, Watchlist entry, and ineligible member cannot open a debrief" do
    film = create_film("Night House")
    library_film = watch(@member, film)
    path = community_posts_path
    sign_in(@member)
    get community_path(q: "Night")
    publication = debrief_publication_fields(path)
    library_film.move_to_watchlist!

    assert_no_difference "Community::PostFilmDebrief.count" do
      post path, params: publication
      assert_response :not_found
      get community_path(q: "Night")
      assert_select ".community-film-debrief-card", count: 0

      reader = member("debrief_no_conduct", accepted: false)
      watch(reader, film)
      sign_in(reader)
      get community_path(q: "Night")
      assert_select "article.community-film-debrief-card h2", text: film.title
      assert_select "form[action=?]", path, count: 0
      post path, params: { authenticity_token: page_token, post_type: "film_debrief", film_id: film.id }
      assert_response :forbidden

      guest = Identity::UserGuest.create!
      watch(guest, film)
      sign_in(guest)
      get library_path
      post path, params: { authenticity_token: page_token, post_type: "film_debrief", film_id: film.id }
      assert_response :forbidden
    end
  end

  test "published debriefs require a registered member who has marked the film Watched" do
    film = create_film("The Night")
    library_film = watch(@member, film)
    debrief = Community::FilmDebriefs::OpenFilmDebrief.call(community_user: @member.community_user, film_id: film.id)
    path = community_post_path(debrief)
    sign_in(@member)
    get path
    assert_response :success
    get edit_community_curation_endorsements_path(debrief)
    assert_response :not_found

    library_film.remove_from_watched!
    get path
    assert_response :not_found
    get community_path
    assert_select ".community-film-debrief-card", count: 0

    guest = Identity::UserGuest.create!
    watch(guest, film)
    sign_in(guest)
    get path
    assert_response :forbidden
    assert Community::PostFilmDebrief.exists?(debrief.id)
  end

  test "the board interleaves published posts and pages search groups in their agreed order" do
    old = 3.days.ago
    recent = 1.day.ago
    newest_curation = create_curation("House Curation New", updated_at: 1.hour.ago)
    second_curation = create_curation("House Curation Old", updated_at: old)
    external_film = create_film("House Outside the Library")
    create_curation("Matching by endorsement", updated_at: recent, film: external_film)

    old_film = create_film("House Debrief Old")
    new_film = create_film("House Debrief New")
    [ old_film, new_film ].each { |film| watch(@member, film) }
    Community::PostFilmDebrief.create!(film: old_film, updated_at: old)
    Community::PostFilmDebrief.create!(film: new_film, updated_at: recent)
    Community::PostFilmDebrief.create!(film: external_film, updated_at: 1.minute.ago)
    placeholders = 9.times.map do |index|
      create_film("House Placeholder #{index + 1}").tap { |film| watch(@member, film) }
    end
    sign_in(@member)

    get community_path
    assert_equal [ newest_curation.title, new_film.title, "Matching by endorsement", old_film.title, second_curation.title ], board_titles

    get community_path(q: "House")
    assert_equal placeholders.map(&:title) + [ new_film.title ], board_titles
    assert_select "a[rel=next][href=?]", community_path(q: "House", page: 2)

    get community_path(q: "House", page: 2)
    assert_equal [ old_film.title, newest_curation.title, "Matching by endorsement", second_curation.title ], board_titles
    assert_select "a[rel=prev][href=?]", community_path(q: "House")
  end

  test "members post multiple roots and branch replies with a shared limit and current board activity" do
    debrief = open_discussion
    path = community_post_comments_path(debrief)
    sign_in(@member)
    get community_post_path(debrief)
    assert_select "textarea[name=body][maxlength='4000']"
    token = form_token(path)

    assert_no_difference "Community::Comment.count" do
      post path, params: { authenticity_token: token, body: "x" * 4_001 }
    end
    assert_response :unprocessable_content
    assert_select ".ui-errors li"
    assert_select "textarea[name=body]", text: "x" * 4_001

    activity = debrief.updated_at
    travel 1.minute do
      post path, params: { authenticity_token: token, body: "x" * 4_000 }
    end
    root = debrief.comments.sole
    assert_equal 4_000, root.content.body.length
    assert_equal debrief.film_id, root.debrief_film_id
    assert_nil root.film_endorsement_id
    assert_nil root.parent_id
    assert_nil root.root_id
    assert_equal @member.community_user, root.content.community_user
    assert_operator debrief.reload.updated_at, :>, activity
    assert_redirected_to community_post_path(debrief, reply: root.id, anchor: "comment-#{root.id}")

    post path, params: { authenticity_token: token, body: "A separate thread." }
    assert_response :see_other
    assert_equal 2, debrief.comments.where(parent_id: nil).count

    get new_reply_community_post_comment_path(debrief, root)
    reply_path = reply_community_post_comment_path(debrief, root)
    activity = debrief.updated_at
    travel 2.minutes do
      post reply_path, params: { authenticity_token: form_token(reply_path), body: "A thoughtful reply." }
    end
    reply = debrief.comments.find_by!(parent: root)
    assert_equal root, reply.root
    assert_nil reply.debrief_film_id
    assert_operator debrief.reload.updated_at, :>, activity
    follow_redirect!
    assert_select "#replies-#{root.id}[open] #comment-#{reply.id}", text: /A thoughtful reply/
    get community_path
    assert_select ".community-film-debrief-card footer p", text: I18n.t("community.curations.comments", count: 3)
  end

  test "all debrief reads and mutations recheck Watched and scope the comment to the post" do
    debrief = open_discussion
    root = publish_comment(debrief, "Spoiler text.")
    other = open_discussion("Other film")
    foreign_root = publish_comment(other, "Foreign text.")
    show_path = community_post_path(debrief)
    comments_path = community_post_comments_path(debrief)
    comment_path = community_post_comment_path(debrief, root)
    sign_in(@member)
    get show_path
    root_token = form_token(comments_path)
    delete_token = form_token(comment_path)

    get new_reply_community_post_comment_path(debrief, foreign_root)
    assert_response :not_found
    get discussion_community_post_path(debrief, parent_id: foreign_root.id)
    assert_response :not_found
    get edit_community_post_comment_path(debrief, foreign_root)
    assert_response :not_found

    reply_path = reply_community_post_comment_path(debrief, root)
    get new_reply_community_post_comment_path(debrief, root)
    reply_token = form_token(reply_path)
    get edit_community_post_comment_path(debrief, root)
    edit_token = form_token(comment_path)
    Library::LibraryFilm.watched.find_by!(user: @member, film: debrief.film).remove_from_watched!

    get show_path
    assert_response :not_found
    get discussion_community_post_path(debrief, parent_id: root.id)
    assert_response :not_found
    assert_no_difference "Community::Comment.count" do
      post comments_path, params: { authenticity_token: root_token, body: "A stale root." }
      assert_response :not_found
      post reply_path, params: { authenticity_token: reply_token, body: "A stale reply." }
      assert_response :not_found
      patch comment_path, params: { authenticity_token: edit_token, body: "A stale edit." }
      assert_response :not_found
      delete comment_path, params: { authenticity_token: delete_token }
      assert_response :not_found
    end
    assert_equal "Spoiler text.", root.content.reload.body

    reader = member("debrief_preview_reader", accepted: false)
    watch(reader, debrief.film)
    sign_in(reader)
    get show_path
    assert_select "article", text: /Spoiler text/
    assert_select "form[action=?]", comments_path, count: 0
    post comments_path, params: { authenticity_token: page_token, body: "Without consent." }
    assert_response :forbidden
  end

  test "editing and deleting debrief comments preserve activity and surviving replies" do
    debrief = open_discussion
    root = publish_comment(debrief, "Original text.")
    reader = member("debrief_reply_author")
    watch(reader, debrief.film)
    reply = Community::Discussions::ManageFilmDebriefDiscussion.publish(post_id: debrief.id, parent_id: root.id,
      community_user: reader.community_user, body: "Surviving reply.").fetch(:content).comment
    activity = debrief.reload.updated_at
    path = community_post_comment_path(debrief, root)

    sign_in(reader)
    get edit_community_post_comment_path(debrief, root)
    assert_response :forbidden
    get community_post_path(debrief)
    delete path, params: { authenticity_token: page_token }
    assert_response :forbidden

    sign_in(@member)
    get edit_community_post_comment_path(debrief, root)
    patch path, params: { authenticity_token: form_token(path), body: "  Original text. " }
    assert_response :see_other
    assert_nil root.content.reload.edited_at
    get edit_community_post_comment_path(debrief, root)
    patch path, params: { authenticity_token: form_token(path), body: "An edited observation." }
    assert_response :see_other
    follow_redirect!
    assert_select "#comment-#{root.id} .community-comment-edited"
    delete path, params: { authenticity_token: form_token(path) }
    assert_response :see_other
    follow_redirect!
    assert_select "#comment-#{root.id}", text: I18n.t("community.curation_replies.removed")
    assert_select "#comment-#{reply.id}", text: /Surviving reply/
    assert_select "#comment-#{root.id} .community-comment-actions", count: 0
    assert_nil root.reload.content
    assert_equal activity, debrief.reload.updated_at
    get new_reply_community_post_comment_path(debrief, root)
    assert_response :not_found

    sign_in(reader)
    get community_post_path(debrief, reply: reply.id)
    reply_path = community_post_comment_path(debrief, reply)
    assert_difference "Community::Comment.count", -1 do
      delete reply_path, params: { authenticity_token: form_token(reply_path) }
    end
    assert_response :see_other
    follow_redirect!
    assert_select "#comment-#{root.id}, #comment-#{reply.id}", count: 0
    assert Community::PostFilmDebrief.exists?(debrief.id)
  end

  test "debrief roots and branches load in bounded pages and a deep link reveals the selected reply" do
    debrief = open_discussion
    limit = Community::Discussions::Discussion::PAGE_SIZE
    roots = (limit + 1).times.map { |i| publish_comment(debrief, "Root #{i}.") }
    parent = roots.last
    replies = (limit + 1).times.map do |i|
      Community::Discussions::ManageFilmDebriefDiscussion.publish(post_id: debrief.id, parent_id: parent.id,
        community_user: @member.community_user, body: "Reply #{i}.").fetch(:content).comment
    end
    sign_in(@member)

    get community_post_path(debrief)
    assert_select "article.community-comment", count: limit
    assert_select "#comment-#{parent.id}", count: 0
    get discussion_community_post_path(debrief, after: roots[-2].id)
    assert_select "article.community-comment", count: 1
    assert_select "#comment-#{parent.id}"

    get discussion_community_post_path(debrief, parent_id: parent.id)
    assert_select "article.community-comment", count: limit
    assert_select "#comment-#{replies.last.id}", count: 0
    get community_post_path(debrief, reply: replies.last.id)
    assert_select "#replies-#{parent.id}[open] #comment-#{replies.last.id}"
  end

  test "closing an account and replaying closure preserve the debrief and surviving reply content" do
    debrief = open_discussion
    root = publish_comment(debrief, "A departing member's comment.")
    other_author = member("debrief_closing_replay")
    viewer = member("debrief_survivor")
    [ other_author, viewer ].each { |reader| watch(reader, debrief.film) }
    replay_root = publish_comment(debrief, "Another departing member's comment.", member: other_author)
    replies = [ root, replay_root ].map do |parent|
      Community::Discussions::ManageFilmDebriefDiscussion.publish(post_id: debrief.id, parent_id: parent.id,
        community_user: viewer.community_user, body: "Surviving content.").fetch(:content).comment
    end
    client = Aws::S3::Client.new(region: "auto", stub_responses: true)
    log = Identity::AccountAdministration::DeletionLog.new(client:, bucket: "fixture", namespace: "debrief")
    Identity::AccountAdministration::ManageRegisteredAccount.new(user_id: @member.id).close_account(deletion_log: log)
    replay_id = other_author.deletion_replay_id
    client.stub_responses(:list_objects_v2, contents: [ { key: "account-deletions/v1/debrief/#{replay_id}.json" } ])
    client.stub_responses(:get_object, body: JSON.generate(account_id: replay_id, recorded_at: Time.current.iso8601))
    assert_equal 1, Identity::AccountAdministration::ReplayAccountDeletions.new(deletion_log: log).call

    assert Community::PostFilmDebrief.exists?(debrief.id)
    assert_nil root.reload.content
    assert_nil replay_root.reload.content
    assert replies.all? { |reply| reply.reload.content.community_user == viewer.community_user }
    sign_in(viewer)
    get community_post_path(debrief, reply: replies.first.id)
    assert_select "#comment-#{root.id}", text: I18n.t("community.curation_replies.removed")
    assert_select "#comment-#{replies.first.id}", text: /Surviving content/
  end

  private

  def debrief_publication_fields(path)
    form = Nokogiri::HTML(response.body).at_css("form.community-film-debrief-create[action='#{path}']")
    %w[authenticity_token post_type film_id].to_h { |name| [ name, form.at_css("input[name='#{name}']")["value"] ] }
  end

  def open_discussion(title = "A watched film")
    film = create_film(title)
    watch(@member, film)
    Community::FilmDebriefs::OpenFilmDebrief.call(community_user: @member.community_user, film_id: film.id)
  end

  def publish_comment(debrief, body, member: @member)
    Community::Discussions::ManageFilmDebriefDiscussion.publish(post_id: debrief.id, parent_id: nil, community_user: member.community_user, body:)
      .fetch(:content).comment
  end

  def member(name, accepted: true)
    create_community_account(email_address: "#{name}@example.test", password: PASSWORD,
      password_confirmation: PASSWORD, email_confirmed_at: Time.current,
      community_username: name, community_avatar_preset: "moth",
      community_code_of_conduct_version: (Community::CodeOfConduct.current.version if accepted),
      community_code_of_conduct_accepted_at: (Time.current if accepted))
  end

  def sign_in(user)
    authentication = Identity::Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def create_film(title)
    Registry::Film.create!(title:, tmdb_metadata: { details: { genres: [ { name: "Horror" } ] } })
  end

  def watch(user, film)
    Library::LibraryFilm.new(user:, film:).add_to_watched!
  end

  def create_curation(title, updated_at:, film: nil)
    travel_to(updated_at) do
      watch(@member, film) if film.present?
      Community::Curations::PublishCuration.call(community_user: @member.community_user, title:, description: "A specific subgenre.",
        reference_film_ids: (film.present? ? [ film.id ] : []), reference_comments: {})
    end
  ensure
    Library::LibraryFilm.find_by!(user: @member, film:).remove_from_watched! if film.present?
  end

  def form_token(path)
    Nokogiri::HTML(response.body).at_css("form[action='#{path}'] input[name=authenticity_token]")["value"]
  end

  def page_token
    Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def board_titles
    Nokogiri::HTML(response.body).css(".community-post-grid > li h2").map(&:text)
  end
end
