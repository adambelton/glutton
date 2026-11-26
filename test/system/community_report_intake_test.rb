require "application_system_test_case"

class CommunityReportIntakeBrowserTest < ApplicationSystemTestCase
  test "a member reports a curation and a moderator reviews the submitted version" do
    password = "a long test password"
    author = Identity::UserRegistered.create!(email_address: "report-browser-author@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, community_username: "FilmWriter",
      community_avatar_preset: "moth", community_code_of_conduct_version: Community::CodeOfConduct.current.version,
      community_code_of_conduct_accepted_at: Time.current)
    moderator = Identity::UserRegistered.create!(email_address: "report-browser-reviewer@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true)
    Community::Moderation::ManageModeratorRoles.grant(actor_id: moderator.id, member_id: moderator.id)
    curation = Community::Curations::PublishCuration.call(author_id: author.id, title: "Isolated landscapes",
      description: "Original description.", reference_film_ids: [], reference_comments: {})

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: moderator.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    visit community_post_path(curation)

    set_viewport(390, 844)
    click_link I18n.t("community.reports.action")
    within ".community-report-evidence" do
      assert_text "Isolated landscapes"
      assert_text "Original description."
    end
    actions = find("form .ui-actions")
    assert_equal({ "display" => "grid", "grid-auto-columns" => "minmax(0px, 1fr)" },
      actions.style("display", "grid-auto-columns"))
    gap = actions.evaluate_script("this.getBoundingClientRect().top - this.previousElementSibling.getBoundingClientRect().bottom")
    assert_in_delta 32, gap, 1
    fill_in I18n.t("community.reports.optional_explanation"), with: "A draft explanation."
    assert_no_difference "Community::Report.count" do
      click_link I18n.t("community.curations.cancel")
      assert_current_path community_post_path(curation)
    end

    reset_viewport
    click_link I18n.t("community.reports.action")
    submit_label = I18n.t("community.reports.submit")
    reason_label = I18n.t("community.reports.reason")
    safety_label = I18n.t("community.reports.reasons.immediate_safety")
    assert_button submit_label, disabled: true
    reason = find_field(reason_label)
    assert_operator reason.style("padding-left").fetch("padding-left").to_f, :>, 0
    select safety_label, from: reason_label
    assert_button submit_label, disabled: false
    fill_in I18n.t("community.reports.optional_explanation"), with: "Please review this."
    click_button submit_label
    assert_current_path community_post_path(curation)
    assert_text I18n.t("community.reports.submitted")

    curation.edit_text(member: author, title: curation.title, description: "Current description.")
    visit community_moderation_path
    assert_text I18n.t("community.reports.high_priority")
    click_link I18n.t("community.reports.identifier", id: Community::Report.sole.id)
    headings = all(".community-report-review > section > h2", count: 4).map(&:text)
    assert_equal %w[members reportable.heading status resolution.title].map { |key| I18n.t("community.reports.#{key}") }, headings
    members = find(".community-report-members")
    assert_equal 2, members.style("grid-template-columns").fetch("grid-template-columns").split.length
    within members do
      assert_text moderator.email_address
      assert_text author.email_address
    end
    assert_text "Community::Post"
    within ".community-report-comparison > section:first-child" do
      assert_selector "h3", text: I18n.t("community.reports.reported_content")
      assert_text "Original description."
    end
    within ".community-report-comparison > section:last-child" do
      assert_selector "h3", text: I18n.t("community.reports.current_content")
      assert_text "Current description."
    end
    click_button I18n.t("community.reports.escalate")
    assert_text I18n.t("community.reports.states.escalated")
    click_link I18n.t("community.reports.back")
    assert_current_path community_moderation_path(state: "escalated")
    within "table.community-report-table" do
      click_link I18n.t("community.reports.identifier", id: Community::Report.sole.id)
    end

    resolve_label = I18n.t("community.reports.resolution.title")
    action_label = I18n.t("community.reports.resolution.action_taken")
    assert_button resolve_label, disabled: true
    within "form .community-report-columns" do
      assert_field I18n.t("community.reports.resolution.outcome")
    end
    disabled_action = find_field(action_label, disabled: true)
    disabled_style = disabled_action.style("background-color", "color", "cursor")
    assert_equal "not-allowed", disabled_style.fetch("cursor")
    select I18n.t("community.reports.resolution.outcomes.violation_confirmed"), from: I18n.t("community.reports.resolution.outcome")
    enabled_style = find_field(action_label).style("background-color", "color", "cursor")
    refute_equal disabled_style.fetch("background-color"), enabled_style.fetch("background-color")
    refute_equal disabled_style.fetch("color"), enabled_style.fetch("color")
    refute_equal disabled_style.fetch("cursor"), enabled_style.fetch("cursor")
    fill_in I18n.t("community.reports.resolution.summary"), with: "A confirmed safety violation. No restriction was needed."
    assert_button resolve_label, disabled: true
    select I18n.t("community.reports.resolution.actions.none"), from: action_label
    assert_button resolve_label, disabled: false
    click_button resolve_label
    assert_text I18n.t("community.reports.resolution.saved")
    assert_text "A confirmed safety violation. No restriction was needed."
    assert_no_text "Original description."
    assert_no_text "Current description."
    assert_no_text "Please review this."
    click_link I18n.t("community.reports.back")
    assert_current_path community_moderation_path(state: "resolved")
    assert_link I18n.t("community.reports.identifier", id: Community::Report.sole.id)
  ensure
    reset_viewport
  end

  test "a moderator chooses a decision and a partial deletion separately" do
    password = "a long test password"
    author = Identity::UserRegistered.create!(email_address: "report-source@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current)
    moderator = Identity::UserRegistered.create!(email_address: "report-deletion@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true)
    Community::Moderation::ManageModeratorRoles.grant(actor_id: moderator.id, member_id: moderator.id)
    curation = Community::PostCommunityCuration.create!(author:, title: "Isolated landscapes",
      description: "Original description.", additional_description: "Reported addition.")
    report = Community::Report.capture(reportable: curation, reporter: moderator, evidence: curation.reportable_attributes,
      reason: "other", explanation: nil)

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: moderator.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    visit community_moderation_report_path(report)

    attribute = I18n.t("community.reports.evidence_attributes.additional_description")
    decision_label = I18n.t("community.reports.resolution.outcome")
    action_label = I18n.t("community.reports.resolution.action_taken")
    accepted = I18n.t("community.reports.resolution.outcomes.violation_confirmed")
    selected_action = I18n.t("community.reports.resolution.delete_attribute", attribute:)
    select accepted, from: decision_label
    select selected_action, from: action_label
    select I18n.t("community.reports.resolution.outcomes.no_violation"), from: decision_label
    assert_field action_label, disabled: true
    select accepted, from: decision_label
    assert_field action_label, with: ""
    select selected_action, from: action_label
    fill_in I18n.t("community.reports.resolution.summary"), with: "The additional text violated the rules."
    resolve_label = I18n.t("community.reports.resolution.title")
    assert_predicate report.reload, :pending?
    assert_equal "Reported addition.", curation.reload.additional_description

    click_button resolve_label
    assert_text I18n.t("community.reports.resolution.saved")
    assert_text I18n.t("community.reports.resolution.actions.deleted_attribute", attribute:)
    assert_nil curation.reload.additional_description
    assert_equal "Original description.", curation.description
  end
end
