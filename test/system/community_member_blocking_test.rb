require "application_system_test_case"

class CommunityMemberBlockingBrowserTest < ApplicationSystemTestCase
  test "a member blocks from a profile and privately unblocks through Account" do
    password = "a long test password"
    version = Community::CodeOfConduct.current.version
    author, reader = %w[BlockAuthor BlockReader].map do |name|
      create_community_account(email_address: "#{name.downcase}@example.test", password:, password_confirmation: password,
        email_confirmed_at: Time.current, community_code_of_conduct_version: version,
        community_code_of_conduct_accepted_at: Time.current, community_username: name, community_avatar_preset: "moth")
    end
    operator = Identity::UserRegistered.create!(email_address: "block-operator@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true)
    Community::Moderation::ManageModeratorRoles.grant(actor_id: operator.id, member_id: reader.id)
    film = Registry::Film.create!(title: "A quiet night")
    [ author, reader ].each { |user| Library::LibraryFilm.new(user:, film:).add_to_watched! }
    debrief = Community::PostFilmDebrief.open_for!(film:)
    comment = debrief.publish_comment(community_user: author.community_user, body: "I heard every floorboard creak.").comment

    visit new_session_path
    fill_in I18n.t("identity.sessions.email"), with: reader.email_address
    fill_in I18n.t("identity.sessions.password"), with: password
    click_button I18n.t("identity.sessions.sign_in")
    assert_current_path library_path

    visit community_post_path(debrief)
    within("#comment-#{comment.id}") { click_link "BlockAuthor" }
    assert_current_path community_member_path(author.community_user)
    block_label = I18n.t("community.member_blocks.block")
    suspend_label = I18n.t("community.suspensions.profile_action")
    within ".community-comment-actions" do
      assert_equal [ I18n.t("community.reports.action"), block_label, suspend_label ], all("a, button").map(&:text)
      assert_equal find_link(suspend_label).style("color", "font-size"), find_button(block_label).style("color", "font-size")
      click_button block_label
    end
    within "dialog[open]" do
      assert_text "Block BlockAuthor?"
      assert_text "You can manage your block list in Account → Community."
      click_button I18n.t("community.curations.cancel")
    end
    assert_no_selector "dialog[open]"
    assert_current_path community_member_path(author.community_user)
    click_button block_label
    within("dialog[open]") { click_button block_label }
    assert_current_path account_community_path
    assert_text I18n.t("community.member_blocks.blocked")

    visit community_post_path(debrief)
    within("#comment-#{comment.id}") do
      assert_text I18n.t("community.member_blocks.comment_unavailable")
      assert_no_text "I heard every floorboard creak."
      assert_no_link I18n.t("community.curations.reply")
      assert_no_link I18n.t("community.reports.action")
    end

    visit account_community_path
    within("section[aria-labelledby='blocked-members']") do
      assert_no_link "BlockAuthor"
      record = Community::MemberBlock.find_by!(blocker: reader.community_user, blocked: author.community_user)
      date = I18n.l(record.created_at, format: :long)
      assert_selector "time[datetime='#{record.created_at.iso8601}']", text: I18n.t("community.member_blocks.blocked_at", time: date)
      heading = element_rectangle(find("h2"))
      member_name = element_rectangle(find("li strong", text: "BlockAuthor"))
      assert_in_delta heading.x, member_name.x, 1

      set_viewport(390, 844)
      member_row = element_rectangle(find("li", text: "BlockAuthor"))
      member_name = element_rectangle(find("li strong", text: "BlockAuthor"))
      unblock = find_button(I18n.t("community.member_blocks.unblock"))
      button = element_rectangle(unblock)
      assert_in_delta member_row.x, button.x, 1
      assert_in_delta member_row.width, button.width, 1
      assert_operator button.y, :>, member_name.y + member_name.height
      unblock.click
      assert_text I18n.t("community.member_blocks.empty")
    end
    visit community_post_path(debrief)
    within("#comment-#{comment.id}") do
      assert_text "I heard every floorboard creak."
      assert_link I18n.t("community.curations.reply")
    end
  ensure
    reset_viewport
  end
end
