require "test_helper"
require "active_support/testing/constant_stubbing"

class CommunityReportIntakeTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::ConstantStubbing

  PASSWORD = "a long test password"

  setup do
    @author = member("report-author", community_username: "FilmWriter", community_avatar_preset: "moth",
      community_code_of_conduct_version: Community::CodeOfConduct.current.version, community_code_of_conduct_accepted_at: Time.current)
    @reporter = member("reporter")
    @operator = member("operator", superuser: true)
    @moderator = member("reviewer")
    Community::Moderation::ManageModeratorRoles.grant(actor_id: @operator.id, member_id: @moderator.id)

    @forgery_protection = [ Community::ReportsController, Community::ModerationReportsController ].index_with(&:allow_forgery_protection)
    @forgery_protection.each_key { |controller| controller.allow_forgery_protection = true }
  end

  teardown do
    @forgery_protection.each { |controller, enabled| controller.allow_forgery_protection = enabled }
  end

  test "an incomplete Community profile can submit a whole curation snapshot once per source" do
    curation = Community::PostCommunityCuration.create!(community_user: @author.community_user, title: "Slow-burn folk horror",
      description: "An original description.", additional_description: "An additional description.")
    sign_in(@reporter)
    get new_community_post_report_path(curation)
    assert_response :success
    assert_select "button[type=submit][data-form-submission-target=submit]:not([disabled])"
    assert_select "select[name='report[reason]'][required]"
    path = community_post_report_path(curation)
    form = fields(path, reason: "private_information", explanation: "Please check this.")

    assert_difference "Community::Report.count" do
      post path, params: form
    end
    assert_redirected_to community_post_path(curation)
    report = curation.reports.sole
    assert_equal curation, report.reportable
    assert_equal({ "title" => "Slow-burn folk horror", "description" => "An original description.",
      "additional_description" => "An additional description." }, report.evidence)
    assert_equal({ "id" => @author.id, "email" => @author.email_address, "username" => "FilmWriter" },
      report.identity_snapshot.fetch("reported_member"))
    assert_equal @reporter.email_address, report.identity_snapshot.fetch("reporter").fetch("email")
    assert_predicate report, :high_priority?

    curation.edit_text(community_user: @author.community_user, title: curation.title, description: "An edited description.")
    assert_equal "An edited description.", report.reload.current_evidence.fetch("description")
    assert_no_difference "Community::Report.count" do
      post path, params: form
    end
    assert_redirected_to community_post_path(curation)
    assert_equal I18n.t("community.reports.already_open"), flash[:alert]
  end

  test "submission refreshes changed evidence and keeps the report draft" do
    curation = publish_curation
    sign_in(@reporter)
    path = community_post_report_path(curation)
    get new_community_post_report_path(curation)
    form = fields(path, reason: "private_information", explanation: "Please review this.")

    curation.edit_text(community_user: @author.community_user, title: "A replacement title", description: curation.description)

    assert_no_difference "Community::Report.count" do
      post path, params: form
    end
    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("community.reports.target_changed")
    assert_select "option[value=private_information][selected]"
    assert_select "textarea[name='report[explanation]']", text: "Please review this."
    assert_select ".community-report-evidence dd", text: "A replacement title"

    post path, params: fields(path, reason: "private_information", explanation: "Please review this.")
    assert_redirected_to community_post_path(curation)
    assert_equal({ "title" => "A replacement title", "description" => "An original description." }, curation.reports.sole.evidence)
  end

  test "debrief reports require current Watched access and reject spoiler claims" do
    film = Registry::Film.create!(title: "Private discussion film")
    library_film = Library::LibraryFilm.new(user: @reporter, film:)
    library_film.add_to_watched!
    debrief = Community::PostFilmDebrief.open_for!(film:)
    comment = debrief.publish_comment(community_user: @author.community_user, body: "A discussion comment.").comment
    reply = comment.publish_reply(community_user: @author.community_user, body: "A reply.").comment
    sign_in(@reporter)
    path = community_post_comment_report_path(debrief, reply)

    get new_community_post_comment_report_path(debrief, reply)
    assert_response :success
    assert_select "option[value=spoilers]", count: 0
    post path, params: fields(path, reason: "spoilers")
    assert_response :unprocessable_content

    get new_community_post_comment_report_path(debrief, comment)
    comment_path = community_post_comment_report_path(debrief, comment)
    post comment_path, params: fields(comment_path)
    assert_response :see_other
    report = Community::Report.sole
    assert_equal comment.content, report.reportable
    assert_equal({ "body" => "A discussion comment." }, report.evidence)

    get new_community_post_comment_report_path(debrief, reply)
    form = fields(path)
    library_film.remove_from_watched!
    assert_no_difference "Community::Report.count" do
      post path, params: form
    end
    assert_response :not_found
  end

  test "removing reported comment text clears its live source while preserving replies and evidence" do
    film = Registry::Film.create!(title: "Discussion film")
    Library::LibraryFilm.new(user: @reporter, film:).add_to_watched!
    debrief = Community::PostFilmDebrief.open_for!(film:)
    comment = debrief.publish_comment(community_user: @author.community_user, body: "Original comment.").comment
    reply = comment.publish_reply(community_user: @author.community_user, body: "A surviving reply.").comment
    form_path = new_community_post_comment_report_path(debrief, comment)
    path = community_post_comment_report_path(debrief, comment)
    sign_in(@reporter)

    get form_path
    post path, params: fields(path)
    assert_response :see_other
    report = comment.content.reports.sole

    comment.edit_body(community_user: @author.community_user, body: "Edited comment.")
    assert_equal({ "body" => "Edited comment." }, report.reload.current_evidence)
    comment.delete_comment!(community_user: @author.community_user)

    assert_nil report.reload.reportable
    assert_nil report.reportable_type
    assert_nil report.reportable_id
    assert_equal({ "body" => "Original comment." }, report.evidence)
    assert_equal "A surviving reply.", reply.reload.content.body
    assert_equal comment.id, reply.parent.id
    get form_path
    assert_response :not_found
  end

  test "moderators can review and escalate, and account closure and replay preserve the evidence" do
    film = Registry::Film.create!(title: "A folk horror film", tmdb_metadata: { details: { genres: [ { name: "Horror" } ] } })
    Library::LibraryFilm.new(user: @author, film:).add_to_watched!
    curation = publish_curation(reference_film_ids: [ film.id ], reference_comments: { film.id => "Opening comment." })
    comment = curation.comments.sole
    sign_in(@reporter)
    source_path = community_post_report_path(curation)
    get new_community_post_report_path(curation)
    post source_path, params: fields(source_path)
    report = Community::Report.sole
    identity_snapshot = report.identity_snapshot
    report_path = community_moderation_report_path(report)

    assert_raises(Community::Errors::ModerationAccessDenied) { report.escalate!(moderator: @operator) }
    assert_predicate report.reload, :pending?

    pending_curation = publish_curation(title: "Other folk horror")
    pending_path = community_post_report_path(pending_curation)
    get new_community_post_report_path(pending_curation)
    post pending_path, params: fields(pending_path)
    assert_redirected_to community_post_path(pending_curation)
    pending = pending_curation.reports.sole
    comment_path = community_post_comment_report_path(curation, comment)
    get new_community_post_comment_report_path(curation, comment)
    post comment_path, params: fields(comment_path)
    assert_response :see_other
    comment_report = comment.content.reports.sole

    sign_in(@operator)
    get report_path
    assert_response :forbidden
    sign_in(@moderator)
    get report_path
    assert_response :success
    escalate_path = escalate_community_moderation_report_path(report)
    patch escalate_path, params: { authenticity_token: input_value(escalate_path, "authenticity_token") }
    assert_redirected_to report_path
    assert_equal "escalated", report.reload.status

    client = Aws::S3::Client.new(region: "auto", stub_responses: true)
    log = Identity::AccountAdministration::DeletionLog.new(client:, bucket: "fixture", namespace: "recovery")
    Identity::AccountAdministration::ManageRegisteredAccount.new(user_id: @reporter.id).close_account(deletion_log: log)
    replay_id = @author.deletion_replay_id
    client.stub_responses(:list_objects_v2, contents: [ { key: "account-deletions/v1/recovery/#{replay_id}.json" } ])
    client.stub_responses(:get_object, body: JSON.generate(account_id: replay_id, recorded_at: Time.current.iso8601))
    assert_equal 1, Identity::AccountAdministration::ReplayAccountDeletions.new(deletion_log: log).call
    # The test transaction would otherwise roll back before PostgreSQL checks deferred constraints.
    Community::Report.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
    assert_nil report.reload.reporter
    assert_nil report.reported_member
    assert_nil report.reportable
    assert_nil report.reportable_type
    assert_nil report.reportable_id
    assert_equal({ "title" => "Slow-burn folk horror", "description" => "An original description." }, report.evidence)
    assert_equal identity_snapshot, report.identity_snapshot
    assert_nil pending.reload.reportable
    assert_nil pending.reportable_type
    assert_nil pending.reportable_id
    assert_predicate pending, :pending?
    assert_equal({ "title" => "Other folk horror", "description" => "An original description." }, pending.evidence)
    assert_equal identity_snapshot, pending.identity_snapshot
    assert_nil comment_report.reload.reportable_type
    assert_nil comment_report.reportable_id
    assert_equal({ "body" => "Opening comment." }, comment_report.evidence)

    get report_path
    assert_response :success
    assert_select ".community-report-comparison > section:first-child dd", text: "An original description."
    assert_select ".community-report-comparison > section:last-child p", text: I18n.t("community.reports.source_deleted")
    assert_select "dd", text: @author.email_address
  end

  test "the moderator queue pages high priority reports ahead of older reports" do
    curation = publish_curation
    sign_in(@reporter)
    path = community_post_report_path(curation)
    get new_community_post_report_path(curation)
    post path, params: fields(path)
    assert_redirected_to community_post_path(curation)
    newer_curation = publish_curation(title: "Other folk horror")
    newer_path = community_post_report_path(newer_curation)
    get new_community_post_report_path(newer_curation)
    post newer_path, params: fields(newer_path, reason: "immediate_safety")
    assert_redirected_to community_post_path(newer_curation)
    earlier = curation.reports.sole
    priority = newer_curation.reports.sole

    sign_in(@operator)
    get community_moderation_path
    assert_response :forbidden

    sign_in(@moderator)
    stub_const(Community::Reporting::BrowseReports, :PAGE_SIZE, 1) do
      get community_moderation_path
      assert_response :success
      assert_select "table.community-report-table th[scope=col]", count: 5
      assert_select "table.community-report-table td a[href=?]", community_moderation_report_path(priority)
      assert_select "a[href=?]", community_moderation_report_path(earlier), count: 0
      assert_select "a[rel=next][href=?]", community_moderation_path(page: 2)

      get community_moderation_path(page: 2)
      assert_response :success
      assert_select "a[href=?]", community_moderation_report_path(earlier)
    end
  end

  test "resolution archives a decision and removes the private evidence in the same change" do
    curation, report = submit_curation_report
    sign_in(@moderator)
    detail = community_moderation_report_path(report)
    path = resolve_community_moderation_report_path(report)
    get detail
    assert_response :success
    assert_select ".community-report-comparison > section", count: 2 do |columns|
      assert_select columns[0], "dd", text: "An original description."
      assert_select columns[1], "dd", text: "An original description."
    end

    patch path, params: resolution_fields(path, summary: "   ")
    assert_response :unprocessable_content
    assert_predicate report.reload, :pending?
    assert_equal({ "title" => "Slow-burn folk horror", "description" => "An original description." }, report.evidence)
    assert_equal "Private report explanation.", report.explanation
    assert_select "option[value=no_violation][selected]"

    patch path, params: resolution_fields(path, summary: "A reviewed allegation with no violation.")
    assert_redirected_to detail
    report.reload
    assert_predicate report, :resolved?
    assert_equal @moderator, report.resolved_by
    assert report.resolved_at.present?
    assert_equal "no_violation", report.resolution_outcome
    assert_equal "other", report.reason
    assert_nil report.reporter
    assert_nil report.reported_member
    assert_nil report.reportable
    assert_nil report.reportable_id
    assert_nil report.reportable_type
    assert_nil report.identity_snapshot
    assert_nil report.evidence
    assert_nil report.explanation
    assert_equal "An original description.", curation.reload.description

    follow_redirect!
    assert_select "p", text: "A reviewed allegation with no violation."
    assert_select ".community-report-evidence", count: 0
    assert_select "p", text: "Private report explanation.", count: 0
    assert_select "dd", text: @reporter.email_address, count: 0
    assert_select "form[action=?]", path, count: 0
    get community_moderation_path
    assert_select "a[href=?]", detail, count: 0
    get community_moderation_path(state: "resolved")
    assert_select "a[href=?]", detail
    assert_select "td", text: I18n.t("community.reports.resolution.outcomes.no_violation")
    assert_select "td", text: I18n.t("community.reports.resolution.actions.none"), count: 0

    sign_in(@reporter)
    get new_community_post_report_path(curation)
    source_path = community_post_report_path(curation)
    assert_difference "Community::Report.count" do
      post source_path, params: fields(source_path)
    end
    assert_redirected_to community_post_path(curation)
  end

  test "a competing escalation invalidates the form and a submitted decision cannot be overwritten" do
    _, report = submit_curation_report
    sign_in(@moderator)
    detail = community_moderation_report_path(report)
    path = resolve_community_moderation_report_path(report)
    get detail
    stale_form = resolution_fields(path, summary: "A decision drafted before escalation.")
    escalation = escalate_community_moderation_report_path(report)
    patch escalation, params: { authenticity_token: input_value(escalation, "authenticity_token") }
    assert_redirected_to detail

    patch path, params: stale_form
    assert_redirected_to detail
    assert_equal I18n.t("community.reports.resolution.review_changed"), flash[:alert]
    assert_equal "escalated", report.reload.status
    assert_equal({ "title" => "Slow-burn folk horror", "description" => "An original description." }, report.evidence)

    get community_moderation_path
    assert_select "a[href=?]", detail, count: 0
    get community_moderation_path(state: "escalated")
    assert_select "nav a[aria-current=page]", text: I18n.t("community.reports.queues.escalated")
    assert_select "table.community-report-table td a[href=?]", detail

    get detail
    form = resolution_fields(path, outcome: "violation_confirmed", action: "none", summary: "Confirmed a violation. No restriction was needed.")
    patch path, params: form
    assert_redirected_to detail
    assert_predicate report.reload, :resolved?
    assert_equal "violation_confirmed", report.resolution_outcome
    assert_nil report.resolution_action
    follow_redirect!
    assert_select "dd", text: I18n.t("community.reports.resolution.outcomes.violation_confirmed")
    assert_select "dd", text: I18n.t("community.reports.resolution.actions.none")

    replacement = form.deep_merge(resolution: { summary: "A second moderator decision." })
    patch path, params: replacement
    assert_redirected_to detail
    assert_equal I18n.t("community.reports.resolution.already_resolved"), flash[:alert]
    assert_equal "Confirmed a violation. No restriction was needed.", report.reload.resolution_summary
  end

  test "the decision and action must agree before resolving a report" do
    curation, report = submit_curation_report
    sign_in(@moderator)
    detail = community_moderation_report_path(report)
    path = resolve_community_moderation_report_path(report)
    get detail
    assert_select "select[name='resolution[action]'][disabled]"
    assert_select "select[name='resolution[outcome]'] option[value=''][disabled][selected]"
    assert_select "select[name='resolution[outcome]'] option:not([disabled])", count: 2 do |options|
      assert_equal %w[violation_confirmed no_violation], options.map { |option| option["value"] }
      assert_equal [ "Violation confirmed", "No violation" ], options.map(&:text)
    end
    assert_select "select[name='resolution[outcome]'] option[value=delete_record]", count: 0

    patch path, params: resolution_fields(path, action: "delete_record", summary: "A rejected report.")
    assert_response :unprocessable_content
    assert_select "[role=alert] li", text: /requires a confirmed violation/
    assert_predicate report.reload, :pending?
    assert Community::Post.exists?(curation.id)

    patch path, params: resolution_fields(path, outcome: "violation_confirmed", summary: "An accepted report.")
    assert_response :unprocessable_content
    assert_select "[role=alert] li", text: /Action taken can't be blank/
    assert_select "select[name='resolution[action]'][required]:not([disabled])"
    assert_predicate report.reload, :pending?
    assert Community::Post.exists?(curation.id)
  end

  test "a moderator who loses the role after opening a report cannot resolve it" do
    curation, report = submit_curation_report
    sign_in(@moderator)
    get community_moderation_report_path(report)
    path = resolve_community_moderation_report_path(report)
    form = resolution_fields(path, outcome: "violation_confirmed", action: "delete_record", summary: "A draft decision.")
    role = Community::ModeratorRole.active.find_by!(member: @moderator)
    Community::Moderation::ManageModeratorRoles.revoke(actor_id: @operator.id, member_id: @moderator.id, role_id: role.id)

    patch path, params: form
    assert_response :forbidden
    assert_predicate report.reload, :pending?
    assert Community::Post.exists?(curation.id)
    assert_equal({ "title" => "Slow-burn folk horror", "description" => "An original description." }, report.evidence)
  end

  test "moderators can remove only a declared attribute from a protected curation" do
    curation, root = protected_curation
    curation.edit_additional_description(community_user: @author.community_user, additional_description: "The reported addition.")
    _, report = submit_curation_report(curation)
    _, other_report = submit_curation_report(curation, reporter: @operator)
    sign_in(@moderator)
    detail = community_moderation_report_path(report)
    path = resolve_community_moderation_report_path(report)
    get detail
    assert_select "select[name='resolution[action]'] option[value^='delete_']", count: 2 do |options|
      assert_equal %w[delete_attribute:additional_description delete_record], options.map { |option| option["value"] }
    end
    assert_select "option[value='delete_attribute:title']", count: 0
    assert_select "option[value=delete_record]"

    forbidden = resolution_fields(path, outcome: "violation_confirmed", action: "delete_attribute:title", summary: "An invalid removal.")
    stale = resolution_fields(path, outcome: "violation_confirmed", action: "delete_attribute:additional_description", summary: "A stale decision.")
    patch path, params: forbidden
    assert_redirected_to detail
    assert_equal I18n.t("community.reports.resolution.deletion_unavailable"), flash[:alert]
    assert_predicate report.reload, :pending?

    curation.edit_additional_description(community_user: @author.community_user, additional_description: "A replacement addition.")
    patch path, params: stale
    assert_redirected_to detail
    assert_equal I18n.t("community.reports.resolution.source_changed"), flash[:alert]
    assert_predicate report.reload, :pending?
    assert_equal "A replacement addition.", curation.reload.additional_description

    get detail
    patch path, params: resolution_fields(path, outcome: "violation_confirmed", action: "delete_attribute:additional_description", summary: "   ")
    assert_response :unprocessable_content
    assert_predicate report.reload, :pending?
    assert_equal "A replacement addition.", curation.reload.additional_description
    assert_select "option[value='delete_attribute:additional_description'][selected]"
    patch path, params: resolution_fields(path, outcome: "violation_confirmed", action: "delete_attribute:additional_description",
      summary: "The added text violated the rules.")
    assert_redirected_to detail
    assert_predicate report.reload, :resolved?
    assert_equal "violation_confirmed", report.resolution_outcome
    assert_equal "delete_attribute:additional_description", report.resolution_action
    assert_nil report.reportable
    assert_nil report.evidence
    assert_nil report.identity_snapshot
    assert_predicate curation.reload, :protected?
    assert_nil curation.additional_description
    assert_equal "An original description.", curation.description
    assert_equal "Slow-burn folk horror", curation.title
    assert root.reload.film_endorsement.active?
    assert_equal 5, curation.comments.where(parent: root).count

    get community_moderation_report_path(other_report)
    assert_select "option[value='delete_attribute:additional_description']", count: 0
    assert_select ".community-report-comparison > section:first-child dd", text: "The reported addition."
    assert_select ".community-report-comparison > section:last-child dd", text: "An original description."
    patch resolve_community_moderation_report_path(other_report), params: resolution_fields(resolve_community_moderation_report_path(other_report),
      outcome: "violation_confirmed", action: "delete_attribute:additional_description", summary: "The attribute is already gone.")
    assert_redirected_to community_moderation_report_path(other_report)
    assert_equal I18n.t("community.reports.resolution.deletion_unavailable"), flash[:alert]
    assert_predicate other_report.reload, :pending?
    get community_moderation_path(state: "resolved")
    assert_select "td", text: I18n.t("community.reports.resolution.outcomes.violation_confirmed")
    assert_select "td", text: I18n.t("community.reports.resolution.actions.deleted_attribute",
      attribute: I18n.t("community.reports.evidence_attributes.additional_description"))
  end

  test "moderators can delete an entire protected curation and its contributions" do
    curation, root = protected_curation
    endorsement = root.film_endorsement
    _, report = submit_curation_report(curation)
    _, other_report = submit_curation_report(curation, reporter: @operator)
    sign_in(@moderator)
    detail = community_moderation_report_path(report)
    path = resolve_community_moderation_report_path(report)
    get detail
    assert_select "option[value^='delete_attribute:']", count: 0
    assert_select "select[name='resolution[action]'] option[value=delete_record]", text: "Delete post"
    patch path, params: resolution_fields(path, outcome: "violation_confirmed", action: "delete_record", summary: "The entire post violated the rules.")
    assert_redirected_to detail
    assert_equal "delete_record", report.reload.resolution_action
    assert_nil report.evidence
    assert_nil report.identity_snapshot
    assert_not Community::Post.exists?(curation.id)
    assert_not Community::Comment.exists?(root.id)
    assert_not Community::FilmEndorsement.exists?(endorsement.id)
    assert_predicate other_report.reload, :pending?
    assert_nil other_report.reportable
    assert_equal "An original description.", other_report.evidence.fetch("description")

    get community_moderation_report_path(other_report)
    assert_select "option[value=delete_record]", count: 0
    assert_select ".community-report-comparison > section:last-child p", text: I18n.t("community.reports.source_deleted")
    get community_post_path(curation)
    assert_response :not_found
    get community_path
    assert_select "a[href=?]", community_post_path(curation), count: 0
    get community_path(q: curation.title)
    assert_select "a[href=?]", community_post_path(curation), count: 0
  end

  test "a source that disappears after review cannot be deleted by that resolution" do
    curation, report = submit_curation_report
    sign_in(@moderator)
    detail = community_moderation_report_path(report)
    path = resolve_community_moderation_report_path(report)
    get detail
    form = resolution_fields(path, outcome: "violation_confirmed", action: "delete_record", summary: "The post violated the rules.")
    curation.delete_curation!(community_user: @author.community_user)

    patch path, params: form
    assert_redirected_to detail
    assert_equal I18n.t("community.reports.resolution.source_changed"), flash[:alert]
    assert_predicate report.reload, :pending?
    assert_equal "An original description.", report.evidence.fetch("description")
  end

  test "moderators delete comment content and preserve surviving replies" do
    film = Registry::Film.create!(title: "Discussion film")
    Library::LibraryFilm.new(user: @reporter, film:).add_to_watched!
    debrief = Community::PostFilmDebrief.open_for!(film:)
    comment = debrief.publish_comment(community_user: @author.community_user, body: "Reported text.").comment
    reply = comment.publish_reply(community_user: @author.community_user, body: "Surviving reply.").comment
    leaf = debrief.publish_comment(community_user: @author.community_user, body: "An unanswered comment.").comment

    [ comment, leaf ].each do |source|
      sign_in(@reporter)
      get new_community_post_comment_report_path(debrief, source)
      report_path = community_post_comment_report_path(debrief, source)
      post report_path, params: fields(report_path)
      assert_response :see_other
      report = source.content.reports.sole
      sign_in(@moderator)
      get community_moderation_report_path(report)
      assert_select "option[value=delete_record]", text: I18n.t("community.reports.resolution.delete_record.community/comment_content")
      assert_select "option[value^='delete_attribute:']", count: 0
      path = resolve_community_moderation_report_path(report)
      patch path, params: resolution_fields(path, outcome: "violation_confirmed", action: "delete_record", summary: "Removed the offending comment.")
      assert_redirected_to community_moderation_report_path(report)
      assert_equal "delete_record", report.reload.resolution_action
    end

    assert_nil comment.reload.content
    assert_equal "Surviving reply.", reply.reload.content.body
    assert_not Community::Comment.exists?(leaf.id)
    sign_in(@reporter)
    get community_post_path(debrief, reply: reply.id)
    assert_response :success
    assert_select "#comment-#{reply.id}", text: /Surviving reply/
    assert_select "#comment-#{comment.id}", text: /Reported text/, count: 0
    get new_community_post_comment_report_path(debrief, comment)
    assert_response :not_found
  end

  private

  def protected_curation
    film = Registry::Film.create!(title: "Reference film", tmdb_metadata: { details: { genres: [ { name: "Horror" } ] } })
    Library::LibraryFilm.new(user: @author, film:).add_to_watched!
    curation = publish_curation(reference_film_ids: [ film.id ], reference_comments: { film.id => "Opening comment." })
    root = curation.comments.sole
    [ @reporter, @operator, @reporter, @operator, @reporter ].each do |author|
      root.publish_reply(community_user: author.community_user || author.create_community_user!, body: "A contribution from another member.")
    end
    curation.protect_from_contributions!
    assert_predicate curation, :protected?
    [ curation, root ]
  end

  def submit_curation_report(curation = publish_curation, reporter: @reporter)
    sign_in(reporter)
    get new_community_post_report_path(curation)
    path = community_post_report_path(curation)
    post path, params: fields(path, explanation: "Private report explanation.")
    assert_redirected_to community_post_path(curation)
    [ curation, curation.reports.where(reporter:).sole ]
  end

  def resolution_fields(path, summary:, outcome: "no_violation", action: nil)
    { authenticity_token: input_value(path, "authenticity_token"), resolution: {
      expected_status: input_value(path, "resolution[expected_status]"),
      revision: input_value(path, "resolution[revision]"), outcome:, action:, summary:
    } }
  end

  def member(name, **attributes)
    create_community_account(email_address: "#{name}@example.test", password: PASSWORD,
      password_confirmation: PASSWORD, email_confirmed_at: Time.current, **attributes)
  end

  def publish_curation(title: "Slow-burn folk horror", reference_film_ids: [], reference_comments: {})
    Community::Curations::PublishCuration.call(community_user: @author.community_user, title:,
      description: "An original description.", reference_film_ids:, reference_comments:)
  end

  def sign_in(user)
    authentication = Identity::Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def fields(path, reason: "other", explanation: nil)
    revision = input_value(path, "report[revision]")
    { authenticity_token: input_value(path, "authenticity_token"), report: { reason:, explanation:, revision: } }
  end

  def input_value(path, name)
    Nokogiri::HTML(response.body).at_css("form[action='#{path}'] input[name='#{name}']")["value"]
  end
end
