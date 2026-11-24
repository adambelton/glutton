require "application_system_test_case"

class SharedPageLayoutTest < ApplicationSystemTestCase
  test "main cards align on desktop and tablet and keep a compact mobile inset" do
    window = current_window
    original_size = window.size
    window.resize_to(1400, 1000)

    standalone_gap = card_gap(new_password_reset_path)
    assert_in_delta standalone_gap, card_gap(new_session_path), 1
    assert_in_delta main_card.rect.x, find(".ui-page-back-above a").rect.x, 1
    sign_in_member

    [ library_path, community_path, account_settings_path, new_rating_path, new_community_curation_path ].each do |path|
      assert_in_delta standalone_gap, card_gap(path), 1, path
    end

    window.resize_to(768, 1000)
    [ library_path, community_path, account_settings_path ].each do |path|
      assert_in_delta standalone_gap, card_gap(path), 1, path
    end

    window.resize_to(390, 844)
    assert_in_delta 16, card_gap(account_settings_path), 1
    [ library_path, community_path ].each do |path|
      assert_operator card_gap(path), :<, standalone_gap
      heading = find(".ui-page-heading")
      assert_selector ".ui-page-heading input[type=search]"
      row = heading.rect
      assert_in_delta 16, main_card.rect.y - (row.y + row.height), 1, path
    end
  ensure
    window.resize_to(*original_size)
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
  end

  private

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
