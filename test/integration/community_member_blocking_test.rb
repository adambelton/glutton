require "test_helper"

class CommunityMemberBlockingTest < ActionDispatch::IntegrationTest
  PASSWORD = "a long test password"

  setup do
    @author = member("AuthorOne")
    @reader = member("ReaderTwo")
    @third = member("ThirdReader")
    controllers = [ Community::PostsController, Community::PostCommentsController, Community::ReportsController ]
    @forgery_protection = controllers.index_with(&:allow_forgery_protection)
    controllers.each { |controller| controller.allow_forgery_protection = true }
  end

  teardown do
    @forgery_protection.each { |controller, enabled| controller.allow_forgery_protection = enabled }
  end

  test "only a posting member can block and each direction is managed privately" do
    partial = member("PartialReader", avatar: nil)
    sign_in(partial)
    get community_member_path(@author.community_user)
    assert_response :success
    assert_select "form[action=?]", block_path(@author), count: 0
    post block_path(@author)
    assert_response :forbidden

    sign_in(@reader)
    get community_member_path(@reader.community_user)
    assert_response :success
    assert_select "form[action=?]", block_path(@reader), count: 0
    assert_no_difference "Community::MemberBlock.count" do
      post block_path(@reader)
      assert_redirected_to account_community_path
      assert_equal I18n.t("community.member_blocks.unavailable"), flash[:alert]
    end

    assert_difference "Community::MemberBlock.count", 1 do
      post block_path(@author)
    end
    assert_redirected_to account_community_path
    follow_redirect!
    assert_select "li", text: /AuthorOne/ do
      assert_select "form[action=?]", block_path(@author)
    end
    assert_no_difference "Community::MemberBlock.count" do
      post block_path(@author)
      assert_equal I18n.t("community.member_blocks.unavailable"), flash[:alert]
    end
    get community_member_path(@author.community_user)
    assert_response :not_found

    sign_in(@author)
    get community_member_path(@reader.community_user)
    assert_response :not_found
    get account_community_path
    assert_select "form[action=?]", block_path(@reader), count: 0
    assert_no_difference "Community::MemberBlock.count" do
      delete block_path(@reader)
      assert_equal I18n.t("community.member_blocks.unavailable"), flash[:alert]
    end
    post block_path(@reader)

    sign_in(@reader)
    delete block_path(@author)
    get community_member_path(@author.community_user)
    assert_response :not_found
    sign_in(@author)
    delete block_path(@reader)
    get community_member_path(@reader.community_user)
    assert_response :success
  end

  test "a debrief hides both members from each other while preserving third-party replies and Watched access" do
    film = Registry::Film.create!(title: "Dark Room")
    [ @author, @reader, @third ].each { |user| Library::LibraryFilm.new(user:, film:).add_to_watched! }
    post_record = Community::PostFilmDebrief.open_for!(film:)
    root = post_record.publish_comment(community_user: @author.community_user, body: "Author private text.").comment
    reader_root = post_record.publish_comment(community_user: @reader.community_user, body: "Reader private text.").comment
    child = root.publish_reply(community_user: @third.community_user, body: "Third party reply.").comment
    post_path = community_post_path(post_record)
    reply_path = reply_community_post_comment_path(post_record, root)
    report_path = community_post_comment_report_path(post_record, root)

    sign_in(@reader)
    get new_reply_community_post_comment_path(post_record, root)
    assert_response :success
    reply_token = form_value(reply_path, "authenticity_token")
    get new_community_post_comment_report_path(post_record, root)
    assert_response :success
    report_fields = fields_for_report(report_path)
    post report_path, params: report_fields
    assert_response :see_other
    report = Community::Report.find_by!(reporter: @reader)

    post block_path(@author)
    get post_path, params: { reply: child.id }
    assert_response :success
    assert_select "#comment-#{root.id}", text: I18n.t("community.member_blocks.comment_unavailable")
    assert_select "#comment-#{child.id}", text: /Third party reply/
    assert_select "a[href=?]", community_member_path(@author.community_user), count: 0
    assert_no_match "Author private text.", response.body
    get discussion_community_post_path(post_record), params: { parent_id: root.id }
    assert_response :success
    assert_select "#comment-#{child.id}", text: /Third party reply/
    get new_reply_community_post_comment_path(post_record, root)
    assert_response :not_found
    assert_no_difference "Community::Comment.count" do
      post reply_path, params: { body: "Stale reply", authenticity_token: reply_token }
      assert_response :not_found
    end
    get new_community_post_comment_report_path(post_record, root)
    assert_response :not_found
    assert_no_difference "Community::Report.count" do
      post report_path, params: report_fields
      assert_response :not_found
    end
    assert_equal "Author private text.", report.reload.evidence.fetch("body")

    sign_in(@author)
    get post_path
    assert_select "#comment-#{reader_root.id}", text: I18n.t("community.member_blocks.comment_unavailable")
    page_token = Nokogiri::HTML(response.body).at_css("meta[name='csrf-token']")["content"]
    post reply_community_post_comment_path(post_record, reader_root), params: { body: "Reverse reply", authenticity_token: page_token }
    assert_response :not_found

    sign_in(@third)
    get post_path
    assert_select "#comment-#{root.id}", text: /Author private text/
    Library::LibraryFilm.find_by!(user: @third, film:).remove_from_watched!
    get post_path
    assert_response :not_found
  end

  test "a curation keeps the artifact and hides its byline and comments from the other member" do
    film = Registry::Film.create!(title: "The Woods", tmdb_metadata: { details: { genres: [ { name: "Horror" } ] } })
    Library::LibraryFilm.new(user: @author, film:).add_to_watched!
    curation = Community::Curations::PublishCuration.call(community_user: @author.community_user,
      title: "Folk horror", description: "Horror set in the woods.", reference_film_ids: [ film.id ],
      reference_comments: { film.id => "An excellent example." })
    root = curation.comments.sole
    sign_in(@reader)
    reply_path = reply_community_post_comment_path(curation, root)
    get new_reply_community_post_comment_path(curation, root)
    assert_response :success
    token = form_value(reply_path, "authenticity_token")
    post block_path(@author)

    get community_path
    assert_select ".community-curation-card h2", text: "Folk horror"
    assert_select ".community-curation-card-author", text: I18n.t("ui.wordmark")
    get community_post_path(curation), params: { reply: root.id }
    assert_select ".community-curation-author", text: I18n.t("ui.wordmark")
    assert_select ".community-nominations h3", text: "The Woods"
    assert_select "#comment-#{root.id}", text: I18n.t("community.member_blocks.comment_unavailable")
    assert_equal @author.community_user, curation.reload.community_user
    assert_no_difference "Community::Comment.count" do
      post reply_path, params: { body: "A stale reply", authenticity_token: token }
      assert_response :not_found
    end
  end

  test "account closure and restore replay remove block relationships and retain reported evidence" do
    sign_in(@reader)
    profile = @author.community_user
    get new_community_member_report_path(profile)
    report_path = community_member_report_path(profile)
    post report_path, params: fields_for_report(report_path)
    assert_response :see_other
    report = Community::Report.find_by!(reporter: @reader)

    post block_path(@author)
    post block_path(@third)
    sign_in(@author)
    post block_path(@reader)
    assert_equal 3, Community::MemberBlock.count
    sign_in(@reader)
    get new_community_member_report_path(profile)
    assert_response :not_found
    operator = member("SiteOperator", superuser: true)
    moderator = member("ReportReviewer")
    Community::Moderation::ManageModeratorRoles.grant(actor_id: operator.id, member_id: moderator.id)
    sign_in(moderator)
    get community_moderation_report_path(report)
    assert_response :success
    assert_select ".community-report-comparison dd", text: "AuthorOne"

    client = Aws::S3::Client.new(region: "auto", stub_responses: true)
    deletion_log = Identity::AccountAdministration::DeletionLog.new(client:, bucket: "fixture", namespace: "recovery")
    Identity::AccountAdministration::ManageRegisteredAccount.new(user_id: @third.id).close_account(deletion_log:)
    assert_equal 2, Community::MemberBlock.count
    replay_id = @author.deletion_replay_id
    client.stub_responses(:list_objects_v2, contents: [ { key: "account-deletions/v1/recovery/#{replay_id}.json" } ])
    client.stub_responses(:get_object, body: JSON.generate(account_id: replay_id, recorded_at: Time.current.iso8601))
    assert_equal 1, Identity::AccountAdministration::ReplayAccountDeletions.new(deletion_log:).call
    assert_empty Community::MemberBlock.all
    assert_nil report.reload.reportable
    assert_equal({ "community_username" => "AuthorOne" }, report.evidence)
  end

  private

  def member(name, avatar: "moth", **permissions)
    code = Community::CodeOfConduct.current
    create_community_account(email_address: "#{name.downcase}@example.test", password: PASSWORD,
      password_confirmation: PASSWORD, email_confirmed_at: Time.current,
      community_code_of_conduct_version: code.version, community_code_of_conduct_accepted_at: Time.current,
      community_username: name, community_avatar_preset: avatar, **permissions)
  end

  def sign_in(user)
    authentication = Identity::Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def block_path(user)
    community_member_block_path(user.community_user)
  end

  def fields_for_report(path)
    { authenticity_token: form_value(path, "authenticity_token"),
      report: { reason: "other", revision: form_value(path, "report[revision]") } }
  end

  def form_value(path, name)
    Nokogiri::HTML(response.body).at_css("form[action='#{path}'] input[name='#{name}']")["value"]
  end
end
