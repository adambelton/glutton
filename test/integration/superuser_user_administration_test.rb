require "test_helper"

class SuperuserUserAdministrationTest < ActionDispatch::IntegrationTest
  setup do
    @actor = create_user("operator", superuser: true)
    @user = create_user("viewer")
    @previous_forgery_protection = Identity::UsersController.allow_forgery_protection
    Identity::UsersController.allow_forgery_protection = true
  end

  teardown do
    Identity::UsersController.allow_forgery_protection = @previous_forgery_protection
  end

  test "the table includes stored guests and deleted rows and opens a selected account" do
    expired = Identity::UserGuest.create!(created_at: 25.hours.ago)
    guest = Identity::UserGuest.create!
    deleted = Identity::UserDeleted.create!
    purged = Identity::UserGuest.create!
    purged.destroy_with_activity!
    bind_session(Identity::Session.create!(user: @actor))

    get admin_users_path
    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
    [ @user, guest, expired, deleted ].each do |user|
      assert_select "tbody a[href=?]", admin_user_path(user.id), text: user.email_address || "User ##{user.id}"
    end
    assert_select "tbody a[href=?]", admin_user_path(purged.id), count: 0
    assert_select "tr", text: /Guest.*Inactive/

    get admin_user_path(@user.id)
    assert_response :success
    assert_select "main > a.admin-back[href=?] + h1", admin_users_path, text: "User #{@user.id}"
    assert_select "a.admin-back[href=?]", admin_users_path do
      assert_select "span[aria-hidden=true]", "←"
      assert_select "span", "Back to users"
    end
    assert_select "section[aria-labelledby=account-details-heading] dd", @user.email_address
    assert_select "section[aria-labelledby=user-sessions-heading]"
    assert_select "a[href=?]", glutton_profile_admin_user_path(@user.id), text: "View Glutton Profile"
    assert_select "main p", "No stored sessions."

    get admin_user_path(purged.id)
    assert_response :not_found
  end

  test "user search filters 10 rows per page and keeps email out of pagination URLs" do
    matches = 11.times.map { |number| create_user("match%02d" % number) }
    bind_session(Identity::Session.create!(user: @actor))
    get admin_users_path
    assert_response :success
    assert_select "tbody tr", count: 10
    assert_select "a[href=?]", admin_users_path(page: 2)

    token = form_token(admin_users_path)
    post admin_users_path, params: { authenticity_token: token, account_email_or_id: " MATCH " }
    assert_response :success
    assert_select "tbody tr", count: 10
    assert_select "tbody a[href=?]", admin_user_path(@actor.id), count: 0
    assert_select "input[type=search][value=MATCH]"
    assert_select ".collection-search-field > a[aria-label=?][href=?]", "Clear search", admin_users_path

    pagination_form = Nokogiri::HTML(response.body).at_css(".admin-page-links form")
    fields = pagination_form.css("input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] }
    assert_equal admin_users_path, pagination_form["action"]
    assert_equal "2", fields.fetch("page")
    assert_equal "MATCH", fields.fetch("account_email_or_id")
    post pagination_form["action"], params: fields
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody a[href=?]", admin_user_path(matches.first.id)
    assert_select ".admin-page-summary p", "Page 2 of 2"

    get admin_users_path
    assert_select "input[type=search][value='']"
    assert_select "a[aria-label=?]:not([hidden])", "Clear search", count: 0

    token = form_token(admin_users_path)
    post admin_users_path, params: { authenticity_token: token, account_email_or_id: @user.id.to_s }
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody a[href=?]", admin_user_path(@user.id)

    token = form_token(admin_users_path)
    post admin_users_path, params: { authenticity_token: token, account_email_or_id: "missing@example.test" }
    assert_response :success
    assert_select "main [role=status]", "No records match your search."
    assert_select "tbody tr", count: 0
  end

  test "private search accepts 254 multibyte characters" do
    bind_session(Identity::Session.create!(user: @actor))
    get admin_users_path
    query = "é" * 254
    token = form_token(admin_users_path)
    post admin_users_path, params: { authenticity_token: token, account_email_or_id: query }
    assert_response :success
    assert_select "input[type=search][value=?]", query

    token = form_token(admin_users_path)
    post admin_users_path, params: { authenticity_token: token, account_email_or_id: query + "é" }
    assert_response :bad_request
  end

  test "revocation expires only the selected browser session and reports a stale form" do
    selected = Identity::Session.create!(user: @user)
    other = Identity::Session.create!(user: @user)
    selected_browser = open_session
    other_browser = open_session
    bind_session(selected, browser: selected_browser)
    bind_session(other, browser: other_browser)
    bind_session(Identity::Session.create!(user: @actor))
    path = session_admin_user_path(@user.id, selected.id)

    selected_browser.get account_settings_path
    assert_equal 200, selected_browser.response.status
    get admin_user_path(@user.id)
    token = form_token(path)
    delete path, params: { authenticity_token: token }
    assert_redirected_to admin_user_path(@user.id)
    follow_redirect!
    assert_select "form[action=?]", path, count: 0
    assert_select "form[action=?]", session_admin_user_path(@user.id, other.id)

    selected_browser.get account_settings_path
    assert_equal new_session_url, selected_browser.response.location
    other_browser.get account_settings_path
    assert_equal 200, other_browser.response.status

    delete path, params: { authenticity_token: token }
    assert_redirected_to admin_user_path(@user.id)
    follow_redirect!
    assert_select "[role=alert]", "That session is no longer available for this user."
  end

  test "a forged target pairing cannot revoke a session on a different user" do
    selected = Identity::Session.create!(user: @user)
    foreign = Identity::Session.create!(user: create_user("foreign"))
    bind_session(Identity::Session.create!(user: @actor))
    get admin_user_path(@user.id)
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]

    delete session_admin_user_path(@user.id, foreign.id), params: { authenticity_token: token }
    assert_redirected_to admin_user_path(@user.id)
    follow_redirect!
    assert_select "[role=alert]", "That session is no longer available for this user."
    assert selected.active?
    assert foreign.active?
  end

  test "self-revocation returns the operator to sign-in" do
    authentication = Identity::Session.create!(user: @actor)
    bind_session(authentication)
    get admin_user_path(@actor.id)
    path = session_admin_user_path(@actor.id, authentication.id)
    delete path, params: { authenticity_token: form_token(path) }
    assert_redirected_to new_session_path
    refute authentication.active?
    get admin_users_path
    assert_redirected_to new_session_path
  end

  test "unprivileged viewers and former superusers cannot inspect or revoke sessions" do
    selected = Identity::Session.create!(user: @user)
    paths = [ admin_users_path, admin_user_path(@user.id) ]
    paths.each do |path|
      get path
      assert_redirected_to new_session_path
    end
    [ Identity::UserGuest.create!, @user ].each do |viewer|
      bind_session(Identity::Session.create!(user: viewer))
      paths.each do |path|
        get path
        assert_response :forbidden
      end
    end

    bind_session(Identity::Session.create!(user: @actor))
    get admin_user_path(@user.id)
    path = session_admin_user_path(@user.id, selected.id)
    token = form_token(path)
    delete path
    assert_response :unprocessable_entity
    assert selected.active?

    Identity::AccountAdministration::RevokeSuperuser.call(user_id: @actor.id, actor_user_id: @actor.id)
    delete path, params: { authenticity_token: token }
    assert_response :forbidden
    assert selected.active?
    paths.each do |entry|
      get entry
      assert_response :forbidden
    end
  end

  private

  def create_user(name, superuser: false)
    Identity::UserRegistered.create!(email_address: "#{name}@example.test", password: "a long test password",
      password_confirmation: "a long test password", email_confirmed_at: Time.current, superuser:)
  end

  def bind_session(authentication, browser: self)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: authentication.user_id } }
    browser.cookies[:session_id] = jar[:session_id]
  end

  def form_token(path)
    Nokogiri::HTML(response.body).at_css("form[action='#{path}'] input[name='authenticity_token']")["value"]
  end
end
