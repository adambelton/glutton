require "test_helper"

class CommunityModeratorAccessTest < ActionDispatch::IntegrationTest
  PASSWORD = "a long test password"

  setup do
    @superuser = registered_member("site-operator", superuser: true)
    @member = registered_member("community-member")
    controllers = [ Identity::UsersController, Community::ModeratorRolesController, Community::CodeOfConductController ]
    @forgery_protection = controllers.index_with(&:allow_forgery_protection)
    controllers.each { |controller| controller.allow_forgery_protection = true }
  end

  teardown do
    @forgery_protection.each { |controller, enabled| controller.allow_forgery_protection = enabled }
  end

  test "superusers can grant and revoke moderation without gaining report access themselves" do
    set_session(self, @superuser)
    get community_moderation_reports_path
    assert_response :forbidden
    get admin_user_path(@member)
    assert_response :success
    role_path = admin_user_community_moderator_role_path(@member)
    grant_token = form_input(role_path, "authenticity_token")

    reviewer = open_session
    set_session(reviewer, @member)
    reviewer.get community_moderation_reports_path
    assert_equal 403, reviewer.response.status

    assert_difference "Community::ModeratorRole.count", 1 do
      post role_path, params: { authenticity_token: grant_token }
    end
    assert_redirected_to admin_user_path(@member)
    role = Community::ModeratorRole.active.find_by!(member: @member)
    assert_equal @superuser, role.granted_by
    assert_predicate role.granted_at, :present?

    reviewer.get community_moderation_reports_path
    assert_equal 200, reviewer.response.status
    assert_nil Nokogiri::HTML(reviewer.response.body).at_css("form[action='#{role_path}']")
    reviewer.get community_path
    board = Nokogiri::HTML(reviewer.response.body)
    assert board.at_css(".community-board-actions a.ui-link[href='#{community_moderation_reports_path}']")

    get admin_user_path(@member)
    delete role_path, params: { authenticity_token: form_input(role_path, "authenticity_token"),
      role_id: form_input(role_path, "role_id") }
    assert_redirected_to admin_user_path(@member)
    assert_equal @superuser, role.reload.revoked_by
    assert_predicate role.revoked_at, :present?

    reviewer.get community_moderation_reports_path
    assert_equal 403, reviewer.response.status
    reviewer.get community_path
    assert_nil Nokogiri::HTML(reviewer.response.body).at_css("a[href='#{community_moderation_reports_path}']")
  end

  test "ordinary members, moderators and guests cannot assign roles through direct requests" do
    role = Community::Moderation::ManageModeratorRoles.grant(actor_id: @superuser.id, member_id: @member.id)
    ordinary_member = registered_member("ordinary-member")
    [ ordinary_member, @member, Identity::UserGuest.create! ].each do |viewer|
      viewer_session = open_session
      set_session(viewer_session, viewer)
      viewer_session.get community_code_of_conduct_path
      token = Nokogiri::HTML(viewer_session.response.body).at_css("meta[name='csrf-token']")["content"]

      viewer_session.post admin_user_community_moderator_role_path(ordinary_member), params: { authenticity_token: token }
      assert_equal 403, viewer_session.response.status
      viewer_session.delete admin_user_community_moderator_role_path(@member),
        params: { authenticity_token: token, role_id: role.id }
      assert_equal 403, viewer_session.response.status
    end
    assert_nil role.reload.revoked_at
    assert_equal [ role.id ], Community::ModeratorRole.active.pluck(:id)
  end

  test "duplicate grants and stale revocations fail without changing a later assignment" do
    set_session(self, @superuser)
    get admin_user_path(@member)
    role_path = admin_user_community_moderator_role_path(@member)
    grant_token = form_input(role_path, "authenticity_token")
    post role_path, params: { authenticity_token: grant_token }
    assert_redirected_to admin_user_path(@member)
    follow_redirect!
    stale_token = form_input(role_path, "authenticity_token")
    stale_role_id = form_input(role_path, "role_id")

    assert_no_difference "Community::ModeratorRole.count" do
      post role_path, params: { authenticity_token: grant_token }
    end
    assert_redirected_to admin_user_path(@member)
    assert_equal I18n.t("community.moderation.role_unavailable"), flash[:alert]

    Community::Moderation::ManageModeratorRoles.revoke(actor_id: @superuser.id, member_id: @member.id, role_id: stale_role_id)
    replacement = Community::Moderation::ManageModeratorRoles.grant(actor_id: @superuser.id, member_id: @member.id)
    delete role_path, params: { authenticity_token: stale_token, role_id: stale_role_id }
    assert_redirected_to admin_user_path(@member)
    assert_equal I18n.t("community.moderation.role_unavailable"), flash[:alert]
    assert_nil replacement.reload.revoked_at
  end

  test "malformed, missing and guest account IDs cannot receive a role" do
    guest = Identity::UserGuest.create!
    set_session(self, @superuser)
    get admin_user_path(guest)
    assert_response :success
    assert_select "form[action=?]", admin_user_community_moderator_role_path(guest), count: 0
    token = Nokogiri::HTML(response.body).at_css("meta[name='csrf-token']")["content"]

    assert_no_difference "Community::ModeratorRole.count" do
      [ "42oops", guest.id, guest.id + 1 ].each do |member_id|
        post admin_user_community_moderator_role_path(member_id), params: { authenticity_token: token }
        assert_response :not_found
      end
    end
  end

  private

  def registered_member(name, superuser: false)
    Identity::UserRegistered.create!(email_address: "#{name}@example.test", password: PASSWORD,
      password_confirmation: PASSWORD, email_confirmed_at: Time.current, superuser:)
  end

  def set_session(browser, user)
    authentication = Identity::Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: user.id } }
    browser.cookies[:session_id] = jar[:session_id]
  end

  def form_input(path, name)
    Nokogiri::HTML(response.body).at_css("form[action='#{path}'] input[name='#{name}']")["value"]
  end
end
