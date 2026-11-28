require "application_system_test_case"

class CommunityNotificationsBrowserTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  test "a mobile member follows one debrief and opens its new comment from the header inbox" do
    password = "a long test password"
    reader = Identity::UserRegistered.create!(email_address: "notification-reader@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current)
    author = create_community_account(email_address: "notification-author@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current,
      community_username: "notification_author", community_avatar_preset: "moth",
      community_code_of_conduct_version: Community::CodeOfConduct.current.version, community_code_of_conduct_accepted_at: Time.current)
    film = Registry::Film.create!(title: "The Quiet Hour", tmdb_metadata: { details: {} })
    [ reader, author ].each { |user| Library::LibraryFilm.new(user:, film:).add_to_watched! }
    debrief = Community::FilmDebriefs::OpenFilmDebrief.call(community_user: author.community_user, film_id: film.id)

    visit new_session_path
    fill_in "Email", with: reader.email_address
    fill_in "Password", with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    set_viewport(390, 850)
    click_link "Notifications"
    assert_current_path notifications_path
    click_link "Notification settings"
    assert_selector "#notification-settings"
    settings_form = find(".community-notification-settings")
    within settings_form do
      save = find_button("Save", disabled: true)
      assert_in_delta element_rectangle(settings_form).width, element_rectangle(save).width, 1
      click_button "All", exact: true
      %w[brilliant pretty_good not_for_me garbage unrated].each do |value|
        assert_selector "input[name='rating_values[]'][value='#{value}']:checked"
      end
      assert_button "Save", disabled: false
      click_button "None", exact: true
      assert_no_selector "input[name='rating_values[]']:checked"
      assert_button "Save", disabled: true
      assert_checked_field "Direct replies to my comments"
      check "Unrated"
      click_button "Save"
    end
    assert_checked_field "Unrated"
    assert_text I18n.t("community.notifications.saved")
    click_button I18n.t("ui.dismiss_notification")

    visit community_post_path(debrief)
    within "#debrief-notifications" do
      click_button "Following", exact: true
    end
    assert_text I18n.t("community.notifications.saved")
    click_button I18n.t("ui.dismiss_notification")
    within "#debrief-notifications" do
      click_button "Follow", exact: true
    end
    assert_text I18n.t("community.notifications.saved")
    within("#debrief-notifications") { assert_button "Following", exact: true }
    click_button I18n.t("ui.dismiss_notification")

    perform_enqueued_jobs(only: Community::DeliverCommentNotificationJob) do
      Community::Discussions::ManageFilmDebriefDiscussion.publish(post_id: debrief.id, parent_id: nil,
        community_user: author.community_user, body: "A new conversation to open from the inbox.")
    end
    visit library_path
    click_link "Notifications (unread)"
    assert_current_path notifications_path
    click_button "New comment on The Quiet Hour"
    assert_text "A new conversation to open from the inbox."
    assert_link "Notifications", href: notifications_path
    assert_no_link "Notifications (unread)"
  ensure
    reset_viewport
  end
end
