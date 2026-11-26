require "application_system_test_case"

class SharedPageLayoutTest < ApplicationSystemTestCase
  test "main cards use the content inset and leave room for headings and back links" do
    set_viewport(1400, 1000)

    standalone_paths = [ new_password_reset_path, community_code_of_conduct_path, privacy_notice_path, terms_of_service_path ]
    standalone_paths.each do |path|
      assert_in_delta 48, card_gap(path), 1, path
    end
    [ privacy_notice_path, terms_of_service_path ].each do |path|
      visit path
      assert_in_delta 1120, main_card.rect.width, 1, path
      within "header.ui-header" do
        assert_link I18n.t("ui.log_in"), href: new_session_path
        assert_link I18n.t("ui.register"), href: new_registration_path
      end
    end

    assert_back_card_gap new_session_path, inset: 48
    assert_in_delta main_card.rect.x, find(".ui-page-back-above a").rect.x, 1
    member = sign_in_member
    curation = Community::Curations::PublishCuration.call(author_id: member.id, title: "Isolated landscapes",
      prompt: "Films with a strong sense of place.", reference_film_ids: [], reference_comments: {})

    [ privacy_notice_path, terms_of_service_path ].each do |path|
      assert_in_delta 48, card_gap(path), 1, path
      within "header.ui-header" do
        assert_link I18n.t("library.browser.title"), href: library_path
        assert_link I18n.t("account.title"), href: account_settings_path
      end
    end
    assert_back_card_gap community_curation_path(curation), inset: 48
    assert_back_card_gap new_community_curation_path, inset: 48
    headed_gap = card_gap(library_path)
    assert_operator headed_gap, :>, 48
    [ community_path, account_settings_path, new_rating_path ].each do |path|
      assert_in_delta headed_gap, card_gap(path), 1, path
    end

    set_viewport(768, 1000)
    [ library_path, community_path, account_settings_path ].each do |path|
      assert_in_delta headed_gap, card_gap(path), 1, path
    end
    assert_in_delta 48, card_gap(community_code_of_conduct_path), 1

    set_viewport(390, 844)
    assert_in_delta 16, card_gap(account_settings_path), 1
    assert_in_delta 16, card_gap(privacy_notice_path), 1
    assert_back_card_gap community_curation_path(curation), inset: 16
    [ library_path, community_path ].each do |path|
      mobile_gap = card_gap(path)
      assert_operator mobile_gap, :<, headed_gap if path == community_path
      heading = find(".ui-page-heading")
      assert_selector ".ui-page-heading input[type=search]"
      row = heading.rect
      assert_in_delta 16, main_card.rect.y - (row.y + row.height), 1, path
    end
  ensure
    reset_viewport
  end

  test "Account tabs share the rating card tab styles and follow the current page" do
    visit new_session_path
    sign_in_member
    film = Registry::Film.create!(title: "Tab styling film")
    visit new_rating_path(film_id: film.id)
    properties = %w[color background-color border-top-color border-bottom-color border-top-left-radius font-weight min-height padding-top]
    rating_style = find('.rating-tabs button[aria-selected="true"]').style(*properties)

    visit account_settings_path
    selected_tab = find('.account-tabs a[aria-current="page"]', text: I18n.t("identity.settings.title"))
    assert_equal rating_style, selected_tab.style(*properties)
    within(".account-tabs") { click_link I18n.t("account.profile") }
    assert_current_path account_taste_profile_path
    assert_selector '.account-tabs a[aria-current="page"]', text: I18n.t("account.profile"), count: 1

    browser = page.driver.browser
    browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 900, deviceScaleFactor: 1, mobile: false)
    row = find(".account-tabs").rect
    first, second, last = all(".account-tabs a", count: 3).map(&:rect)
    assert_equal 1, [ first.y, second.y, last.y ].uniq.size
    assert_in_delta first.width.fdiv(row.width), last.width.fdiv(row.width), 0.03
    assert_in_delta first.width.fdiv(row.width), second.width.fdiv(row.width), 0.03
    assert_in_delta find(".account-page").rect.width, last.x + last.width - first.x, 1
    within(".account-tabs") { click_link I18n.t("community.title") }
    assert_current_path account_community_path
    assert_selector '.account-tabs a[aria-current="page"]', text: I18n.t("community.title"), count: 1
  ensure
    browser&.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "Small account dialog actions fill their rows at desktop and mobile widths" do
    visit new_session_path
    sign_in_member
    visit account_settings_path

    [ 1400, 320 ].each do |width|
      set_viewport(width, 780)
      %w[change_email change_password delete_title].each do |action|
        label = I18n.t("identity.settings.#{action}")
        assert_account_edit_button_below_field(label) if width == 320 && action != "delete_title"
        click_button label
        within "dialog[open]" do
          heading = find("h2").rect
          cancel, submit = all(".ui-actions button", count: 2).map(&:rect)
          assert_in_delta heading.x, cancel.x, 1
          assert_in_delta heading.x + heading.width, submit.x + submit.width, 1
          assert_equal cancel.y, submit.y
          assert_in_delta cancel.width, submit.width, 1
          click_button I18n.t("identity.settings.cancel")
        end
        assert_no_selector "dialog[open]"
      end
    end

    within(".account-tabs") { click_link I18n.t("community.title") }
    assert_current_path account_community_path
    %w[community_username community_avatar].each do |field|
      assert_account_edit_button_below_field(I18n.t("identity.settings.#{field}.change"))
    end
  ensure
    reset_viewport
  end

  private

  def assert_account_edit_button_below_field(label)
    row = find(".account-settings-row", text: label)
    field = row.find(":scope > :is(.account-settings-field, .account-avatar-current)").rect
    button = row.find_button(label).rect

    assert_operator button.y, :>, field.y + field.height
    assert_in_delta row.rect.x, button.x, 1
    assert_in_delta row.rect.width, button.width, 1
  end

  def sign_in_member
    password = "a long test password"
    member = Identity::UserRegistered.create!(email_address: "page-layout@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true,
      community_username: "Curator", community_avatar_preset: "moth",
      community_code_of_conduct_version: Community::CodeOfConduct.current.version,
      community_code_of_conduct_accepted_at: Time.current)
    fill_in I18n.t("identity.sessions.email"), with: member.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    member
  end

  def assert_back_card_gap(path, inset:)
    visit path
    header = find("header.ui-header").rect
    back_row = find(".ui-page-back-above").rect
    assert_in_delta inset, back_row.y - (header.y + header.height), 1, path
    assert_in_delta 8, main_card.rect.y - (back_row.y + back_row.height), 1, path
  end

  def card_gap(path)
    visit path
    assert_current_path path
    header = find("header.ui-header").rect
    main_card.rect.y - (header.y + header.height)
  end

  def main_card
    find("main.ui-card, main > .ui-page-body.ui-card")
  end
end
