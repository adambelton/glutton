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
      assert_in_delta 1120, element_rectangle(main_card).width, 1, path
      within "header.ui-header" do
        assert_link I18n.t("ui.log_in"), href: new_session_path
        assert_link I18n.t("ui.register"), href: new_registration_path
      end
    end

    assert_back_card_gap new_session_path, inset: 48
    assert_in_delta element_rectangle(main_card).x, element_rectangle(find(".ui-page-back-above a")).x, 1
    member = sign_in_member
    curation = Community::Curations::PublishCuration.call(community_user: member.community_user, title: "Isolated landscapes",
      description: "Films with a strong sense of place.", reference_film_ids: [], reference_comments: {})

    [ privacy_notice_path, terms_of_service_path ].each do |path|
      assert_in_delta 48, card_gap(path), 1, path
      within "header.ui-header" do
        assert_link I18n.t("library.browser.title"), href: library_path
        assert_link I18n.t("account.title"), href: account_settings_path
      end
    end
    assert_back_card_gap community_post_path(curation), inset: 48
    assert_in_delta 48, card_gap(new_community_post_path), 1
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
    assert_back_card_gap community_post_path(curation), inset: 16
    [ library_path, community_path ].each do |path|
      mobile_gap = card_gap(path)
      assert_operator mobile_gap, :<, headed_gap if path == community_path
      heading = find(".ui-page-heading")
      assert_selector ".ui-page-heading input[type=search]"
      row = element_rectangle(heading)
      assert_in_delta 16, element_rectangle(main_card).y - (row.y + row.height), 1, path
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

    set_viewport(320, 900)
    row = element_rectangle(find(".account-tabs"))
    first, second, last = all(".account-tabs a", count: 3).map { |element| element_rectangle(element) }
    assert_equal 1, [ first.y, second.y, last.y ].uniq.size
    assert_in_delta first.width.fdiv(row.width), last.width.fdiv(row.width), 0.03
    assert_in_delta first.width.fdiv(row.width), second.width.fdiv(row.width), 0.03
    assert_in_delta element_rectangle(find(".account-page")).width, last.x + last.width - first.x, 1
    within(".account-tabs") { click_link I18n.t("community.title") }
    assert_current_path account_community_path
    assert_selector '.account-tabs a[aria-current="page"]', text: I18n.t("community.title"), count: 1
  ensure
    reset_viewport
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
          heading = element_rectangle(find("h2"))
          cancel, submit = all(".ui-actions button", count: 2).map { |element| element_rectangle(element) }
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
    %w[username avatar].each do |field|
      assert_account_edit_button_below_field(I18n.t("community.profile.#{field}.change"))
    end
  ensure
    reset_viewport
  end

  private

  def assert_account_edit_button_below_field(label)
    row = find(".account-settings-row", text: label)
    field = element_rectangle(row.find(":scope > :is(.account-settings-field, .account-avatar-current)"))
    button = element_rectangle(row.find_button(label))

    assert_operator button.y, :>, field.y + field.height
    assert_in_delta element_rectangle(row).x, button.x, 1
    assert_in_delta element_rectangle(row).width, button.width, 1
  end

  def sign_in_member
    password = "a long test password"
    member = create_community_account(email_address: "page-layout@example.test", password:,
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
    header = element_rectangle(find("header.ui-header"))
    back_row = element_rectangle(find(".ui-page-back-above"))
    assert_in_delta inset, back_row.y - (header.y + header.height), 1, path
    assert_in_delta 8, element_rectangle(main_card).y - (back_row.y + back_row.height), 1, path
  end

  def card_gap(path)
    visit path
    assert_current_path path
    header = element_rectangle(find("header.ui-header"))
    element_rectangle(main_card).y - (header.y + header.height)
  end

  def main_card
    find("main.ui-card, main > .ui-page-body.ui-card")
  end
end
