require "application_system_test_case"

class CommunityReportIntakeBrowserTest < ApplicationSystemTestCase
  test "a member reports a curation field and a moderator reviews the submitted version" do
    password = "a long test password"
    author = Identity::UserRegistered.create!(email_address: "report-browser-author@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, community_username: "FilmWriter",
      community_avatar_preset: "moth", community_code_of_conduct_version: Community::CodeOfConduct.current.version,
      community_code_of_conduct_accepted_at: Time.current)
    moderator = Identity::UserRegistered.create!(email_address: "report-browser-reviewer@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true)
    Community::Moderation::ManageModeratorRoles.grant(actor_id: moderator.id, member_id: moderator.id)
    curation = Community::Curations::PublishCuration.call(author_id: author.id, title: "Isolated landscapes",
      prompt: "Original description.", reference_film_ids: [], reference_comments: {})

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: moderator.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    visit community_post_path(curation)

    click_link I18n.t("community.reports.action")
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

    click_link I18n.t("community.reports.action")
    submit_label = I18n.t("community.reports.submit")
    reason_label = I18n.t("community.reports.reason")
    safety_label = I18n.t("community.reports.reasons.immediate_safety")
    assert_button submit_label, disabled: true
    select safety_label, from: reason_label
    assert_button submit_label, disabled: true
    select I18n.t("community.reports.choose_reason"), from: reason_label
    radio = find("input[name='report[part]'][value='description']")
    caption = radio.sibling("strong").rect
    assert_operator caption.x, :>, radio.rect.x + radio.rect.width
    radio.click
    assert_button submit_label, disabled: true
    reason = find_field(reason_label)
    assert_operator reason.style("padding-left").fetch("padding-left").to_f, :>, 0
    select safety_label, from: reason_label
    assert_button submit_label, disabled: false
    fill_in I18n.t("community.reports.optional_explanation"), with: "Please review this."
    click_button submit_label
    assert_current_path community_post_path(curation)
    assert_text I18n.t("community.reports.submitted")

    curation.edit_text(member: author, title: curation.title, prompt: "Current description.")
    visit community_moderation_path
    assert_text I18n.t("community.reports.high_priority")
    click_link I18n.t("community.reports.identifier", id: Community::Report.sole.id)
    assert_text "Original description."
    assert_text "Current description."
    click_button I18n.t("community.reports.escalate")
    assert_text I18n.t("community.reports.states.escalated")
  end
end
