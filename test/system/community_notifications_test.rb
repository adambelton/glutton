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
    film = Registry::Film.create!(title: "The Quiet Hour", tmdb_metadata: { details: { genres: [ { name: "Horror" } ] } })
    [ reader, author ].each { |user| Library::LibraryFilm.new(user:, film:).add_to_watched! }
    debrief = Community::FilmDebriefs::OpenFilmDebrief.call(community_user: author.community_user, film_id: film.id)

    visit new_session_path
    fill_in "Email", with: reader.email_address
    fill_in "Password", with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path
    set_viewport(390, 850)
    navigation = find("select.ui-primary-navigation")
    assert_equal I18n.t("community.notifications.title"), navigation.all("option").last.text
    navigation.select(I18n.t("community.notifications.title"))
    assert_current_path notifications_path
    assert_select I18n.t("ui.navigation"), selected: I18n.t("community.notifications.title")
    click_link "Notification settings"
    assert_selector "#notification-settings"
    settings_form = find(".community-notification-settings")
    within settings_form do
      assert_selector "legend", exact_text: "Film Debrief Posts"
      assert_selector "legend", exact_text: "Community Curation Posts"
      assert_selector "#debrief-opening-comments", exact_text: "New opening comments on films I've watched"
      set_viewport(1400, 850)
      desktop_widths = [ find_button("All", exact: true), find_button("None", exact: true), find_button("Save", disabled: true) ]
        .map { |button| element_rectangle(button).width }
      assert_equal 1, desktop_widths.uniq.size

      set_viewport(390, 850)
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
      within("fieldset", text: "All Posts") do
        assert_checked_field "Direct replies to my comments"
      end
      assert_checked_field "New opening comments on my curations"
      assert_unchecked_field "New opening comments on films I endorse"
      uncheck "New opening comments on my curations"
      check "New opening comments on films I endorse"
      check "Not Rated"
      click_button "Save"
    end
    assert_checked_field "Not Rated"
    assert_unchecked_field "New opening comments on my curations"
    assert_checked_field "New opening comments on films I endorse"
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

    curation = Community::Curations::PublishCuration.call(community_user: author.community_user, title: "Quiet films",
      description: "A collection of quiet films.", reference_film_ids: [ film.id ], reference_comments: {})
    visit community_post_path(curation)
    curation_button = "#curation-notifications button"
    film_button = "#nomination-#{film.id} header button[name='following']"
    find(curation_button, exact_text: "Follow").click
    assert_selector curation_button, exact_text: "Following"
    find(film_button, exact_text: "Following").click
    assert_selector film_button, exact_text: "Follow"
    find(curation_button, exact_text: "Following").click
    assert_selector curation_button, exact_text: "Follow"
    assert_selector film_button, exact_text: "Follow"
    find(film_button, exact_text: "Follow").click
    assert_selector film_button, exact_text: "Following"
    assert_selector curation_button, exact_text: "Follow"
  ensure
    reset_viewport
  end
end
