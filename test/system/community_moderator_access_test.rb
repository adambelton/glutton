require "application_system_test_case"

class CommunityModeratorWorkspaceTest < ApplicationSystemTestCase
  test "a site superuser manages the moderator assignment from the Admin account page" do
    password = "a long test password"
    superuser = Identity::UserRegistered.create!(email_address: "moderation-operator@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true)
    member = create_community_account(email_address: "moderation-member@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, community_username: "NightWatcher",
      community_avatar_preset: "moth", community_code_of_conduct_version: Community::CodeOfConduct.current.version,
      community_code_of_conduct_accepted_at: Time.current)

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: superuser.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    visit admin_user_path(member)

    click_button I18n.t("community.moderation.grant")
    assert_current_path admin_user_path(member)
    assert_button I18n.t("community.moderation.revoke")
    assert Community::ModeratorRole.active.exists?(member:)

    using_session(:moderator) do
      visit new_session_path
      fill_in I18n.t("identity.sessions.email"), with: member.email_address
      fill_in I18n.t("identity.sessions.password"), with: password
      click_button I18n.t("identity.sessions.sign_in")
      assert_current_path library_path
      visit community_path
      set_viewport(390, 844)
      within ".community-board-actions" do
        assert_link I18n.t("community.curations.create")
        assert_no_link I18n.t("community.moderation.title")
      end
      reset_viewport
      within ".ui-page-heading" do
        assert_field I18n.t("community.search.label")
        assert_no_link I18n.t("community.moderation.title")
      end
      within ".community-board-actions" do
        assert_link I18n.t("community.curations.create")
        click_link I18n.t("community.moderation.title")
      end
      assert_current_path community_moderation_reports_path
    ensure
      reset_viewport
    end

    visit admin_user_path(member)
    click_button I18n.t("community.moderation.revoke")
    assert_current_path admin_user_path(member)
    assert_button I18n.t("community.moderation.grant")
    refute Community::ModeratorRole.active.exists?(member:)
  end
end
