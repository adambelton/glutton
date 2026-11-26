require "application_system_test_case"

class CommunityConductAcceptanceTest < ApplicationSystemTestCase
  test "a regular member can open Community after Library and accept from Account before choosing a username" do
    password = "a long test password"
    member = Identity::UserRegistered.create!(email_address: "conduct-browser@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current)
    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: member.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_selector ".ui-nav a[href='#{library_path}'] + a[href='#{community_path}']", exact_text: I18n.t("community.title")
    assert_selector ".ui-primary-navigation option[value='#{library_path}'] + option[value='#{community_path}']:enabled", visible: :all
    within(".ui-nav") { click_link I18n.t("community.title") }
    assert_current_path community_path
    assert_no_selector ".community-conduct-text"
    click_link I18n.t("community.curations.complete_setup")
    assert_current_path account_community_path

    assert_selector ".community-conduct-text", text: I18n.t("community.code_of_conduct_v1.intro")
    assert_selector ".community-conduct-text + form input[name=accepted]"
    assert_link I18n.t("community.code_of_conduct_v1.copyright.email")
    assert_no_field I18n.t("identity.settings.community_username.label")
    assert_no_button I18n.t("identity.settings.community_avatar.choose")

    assert_button I18n.t("community.conduct.accept"), disabled: true
    check I18n.t("community.conduct.agreement")
    click_button I18n.t("community.conduct.accept")
    assert_current_path account_community_path
    assert_selector "section > p", exact_text: I18n.t("community.conduct.accepted")
    assert_no_selector ".community-conduct-text"
    assert_field I18n.t("identity.settings.community_username.label")
    assert_button I18n.t("identity.settings.community_avatar.choose")
    assert_nil member.reload.community_username

    click_link I18n.t("community.conduct.read")
    assert_current_path community_code_of_conduct_path
    assert_selector "h1", exact_text: I18n.t("community.conduct.title")
    within("header .ui-nav") { assert_link I18n.t("account.title"), href: account_settings_path }
    assert_no_selector "header .ui-auth-links"

    set_viewport(390, 950)
    visit library_path
    find("select.ui-primary-navigation").find("option", text: I18n.t("community.title"), exact_text: true).select_option
    assert_current_path community_path
    assert_no_text I18n.t("community.conduct.accepted")
    assert_no_link I18n.t("community.conduct.read")
    assert_no_button I18n.t("community.conduct.accept")
  ensure
    reset_viewport
  end
end
