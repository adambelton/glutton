require "application_system_test_case"

class CommunityAvatarTest < ApplicationSystemTestCase
  test "a member chooses and changes a Community avatar" do
    password = "a long test password"
    user = Identity::UserRegistered.create!(email_address: "avatar-browser@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current)
    Community::Membership::AcceptCodeOfConduct.call(user_id: user.id, displayed_version: Community::CodeOfConduct.current.version, accepted: true)
    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: user.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    visit account_community_path

    assert_no_selector ".account-avatar-current img"
    click_button I18n.t("identity.settings.community_avatar.choose")
    save = I18n.t("identity.settings.community_avatar.save")
    assert_button save, disabled: true
    assert_selector "label.account-avatar-choice", count: 24
    assert_selector ".account-avatar-choice img[src*='community-avatars/']", count: 24
    assert_equal 24, all(".account-avatar-choice img").map { |image| image[:src] }.uniq.size
    moth = I18n.t("identity.settings.community_avatar.presets.moth")
    assert_selector "label.account-avatar-choice input[aria-label='#{moth}']", visible: :all
    assert_no_text moth
    find("label.account-avatar-choice:has(input[value=moth])").click
    assert_button save, disabled: false
    click_button save

    assert_current_path account_community_path
    assert_selector ".account-avatar-current img[alt='#{moth}']"
    assert_selector ".account-avatar-current img[src*='community-avatars/moth']" do |image|
      image.evaluate_script(<<~JS)
        (() => {
          const { width, height } = this.getBoundingClientRect()
          return this.complete && this.naturalWidth === 512 && width === 128 && height === 128 &&
            getComputedStyle(this).borderTopWidth === "1px"
        })()
      JS
    end
    assert_no_text moth
    assert_equal "moth", user.reload.community_avatar_preset

    click_button I18n.t("identity.settings.community_avatar.change")
    assert_selector 'input[value="moth"]:checked', visible: :all
    assert_button save, disabled: true
    find("label.account-avatar-choice:has(input[value=spaceman_mask])").click
    assert_button save, disabled: false
    find("label.account-avatar-choice:has(input[value=moth])").click
    assert_button save, disabled: true
    find("label.account-avatar-choice:has(input[value=spaceman_mask])").click
    click_button save

    assert_current_path account_community_path
    assert_selector ".ui-toast", text: I18n.t("identity.settings.community_avatar.saved")
    spaceman = I18n.t("identity.settings.community_avatar.presets.spaceman_mask")
    assert_selector ".account-avatar-current img[alt='#{spaceman}']"
    assert_equal "spaceman_mask", user.reload.community_avatar_preset
    visit account_community_path
    assert_selector ".account-avatar-current img[alt='#{spaceman}']"
  end
end
