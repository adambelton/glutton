require "application_system_test_case"

class CommunityConductAcceptanceTest < ApplicationSystemTestCase
  test "a superuser can open Community after Library and accept from Account before choosing a username" do
    password = "a long test password"
    member = Identity::UserRegistered.create!(email_address: "conduct-browser@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true)
    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: member.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_selector ".ui-nav a[href='#{library_path}'] + a[href='#{community_path}']", exact_text: I18n.t("community.title")
    assert_selector ".ui-primary-navigation option[value='#{library_path}'] + option[value='#{community_path}']:enabled", visible: :all
    within(".ui-nav") { click_link I18n.t("community.title") }
    assert_current_path community_path
    within(".ui-nav") { click_link I18n.t("account.title") }
    within(".account-tabs") { click_link I18n.t("community.title") }
    assert_current_path account_community_path

    assert_selector ".community-conduct-text", text: I18n.t("community.code_of_conduct_v1.intro")
    assert_selector ".community-conduct-text + form input[name=accepted]"
    assert_link I18n.t("community.code_of_conduct_v1.copyright.email")
    assert_no_field I18n.t("identity.settings.community_username.label")
    assert_no_button I18n.t("identity.settings.community_avatar.choose")

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

    visit community_path
    assert_selector "section > p", exact_text: I18n.t("community.conduct.accepted")
    assert_no_button I18n.t("community.conduct.accept")
  end

  test "a regular member can read the Coming soon tooltip on both locked entries" do
    password = "a long test password"
    member = Identity::UserRegistered.create!(email_address: "preview-locked-browser@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current)
    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: member.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    locked_link = find(".ui-nav a[href='#{library_path}'] + [aria-describedby='community-nav-tooltip'][aria-disabled='true']")
    assert_no_selector "#community-nav-tooltip"
    locked_link.hover
    assert_selector "#community-nav-tooltip[role=tooltip]", exact_text: I18n.t("community.coming_soon")
    assert_no_link I18n.t("community.title")

    within(".ui-nav") { click_link I18n.t("account.title") }
    locked_tab = find(".account-tabs [aria-describedby='account-community-tooltip'][aria-disabled='true']")
    assert_no_selector "#account-community-tooltip"
    locked_tab.send_keys(:shift)
    assert_selector "#account-community-tooltip[role=tooltip]", exact_text: I18n.t("community.coming_soon")
    assert_current_path account_settings_path
  end
end
