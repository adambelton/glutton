require "test_helper"

class AccountSettingsTest < ActionDispatch::IntegrationTest
  PASSWORD = "a long test password"
  NEW_PASSWORD = "a different long password"

  setup do
    @forgery_protection = AccountSettingsController.allow_forgery_protection
    @profile_forgery_protection = Community::ProfilesController.allow_forgery_protection
    @session_forgery_protection = SessionsController.allow_forgery_protection
    AccountSettingsController.allow_forgery_protection = true
    Community::ProfilesController.allow_forgery_protection = true
    SessionsController.allow_forgery_protection = true
    AccountSettingsController::RATE_LIMIT_STORE.clear
    SessionsController::RATE_LIMIT_STORE.clear
    @previous_origin = ENV["APP_ORIGIN"]
    ENV["APP_ORIGIN"] = "https://glutton.example"
    @user = registered_user("settings@example.test")
    Community::Membership::SetUpProfile.call(user_id: @user.id, displayed_version: Community::CodeOfConduct.current.version, accepted: true)
  end

  teardown do
    ENV["APP_ORIGIN"] = @previous_origin
    AccountSettingsController.allow_forgery_protection = @forgery_protection
    Community::ProfilesController.allow_forgery_protection = @profile_forgery_protection
    SessionsController.allow_forgery_protection = @session_forgery_protection
    AccountSettingsController::RATE_LIMIT_STORE.clear
    SessionsController::RATE_LIMIT_STORE.clear
  end

  test "account settings reject signed-out viewers and guests" do
    get account_settings_path
    assert_redirected_to new_session_path
    sign_in(Identity::UserGuest.create!)
    get account_settings_path
    assert_response :forbidden
  end

  test "a member signs in with email and claims and changes only their own public username" do
    other = registered_user("someone-else@example.test")
    get new_session_path
    post session_path, params: { email_address: @user.email_address, password: PASSWORD, authenticity_token: csrf_token(session_path) }
    assert_response :see_other

    get account_settings_path
    assert_response :success
    assert_select ".account-tabs a[href='#{account_community_path}']", text: I18n.t("community.title")
    assert_select "input#community_username", count: 0

    get account_community_path
    assert_response :success
    assert_select ".account-tabs a[aria-current=page][href='#{account_community_path}']"
    assert_select 'input#community_username[autocomplete="off"][data-bwignore="true"][data-1p-ignore="true"]', count: 1
    assert_select "input#community_username[value]", count: 0
    assert_select "button", text: I18n.t("identity.settings.cancel"), count: 0
    patch account_community_username_path, params: { authenticity_token: csrf_token(account_community_username_path),
      community_username: "Scream_Queen", user_id: other.id }
    assert_redirected_to account_community_path
    assert_equal "Scream_Queen", @user.reload.community_user&.community_username
    assert_nil other.reload.community_user&.community_username

    follow_redirect!
    assert_select ".account-settings-field p", "Scream_Queen"
    assert_select "button", text: I18n.t("community.profile.username.change")
    assert_select "input#community_username", count: 0

    get account_community_path(edit: "username")
    assert_select 'input#community_username[value="Scream_Queen"]'
    assert_select "button[form='cancel-community-username']", text: I18n.t("identity.settings.cancel")
    assert_select "form#cancel-community-username[action='#{account_community_path}'][method=get]"
    patch account_community_username_path, params: { authenticity_token: csrf_token(account_community_username_path),
      community_username: "scream_queen" }
    assert_redirected_to account_community_path
    assert_equal "scream_queen", @user.reload.community_user&.community_username
    follow_redirect!
    assert_select ".account-settings-field p", "scream_queen"
    assert_select "input#community_username", count: 0
  end

  test "direct username submissions require account access and CSRF" do
    get account_community_path
    assert_redirected_to new_session_path

    get new_session_path
    patch account_community_username_path, params: { authenticity_token: page_csrf_token, community_username: "Scream_Queen" }
    assert_response :unauthorized

    guest = Identity::UserGuest.create!
    sign_in(guest)
    get account_community_path
    assert_response :forbidden

    get new_session_path
    patch account_community_username_path, params: { authenticity_token: page_csrf_token, community_username: "Scream_Queen" }
    assert_response :forbidden
    assert_not Community::CommunityUser.exists?(guest.id)

    sign_in(@user)
    patch account_community_username_path, params: { community_username: "Scream_Queen" }
    assert_response :unprocessable_entity
    assert_nil @user.reload.community_user&.community_username
  end

  test "invalid avatar submissions preserve the saved avatar" do
    Community::Membership::ManageProfile.new(community_user: @user.community_user).choose_community_avatar(preset: "moth")
    sign_in(@user)

    [ nil, "unknown", [ "skull" ] ].each do |preset|
      get account_community_path(edit: "avatar")
      patch account_community_avatar_path, params: { authenticity_token: csrf_token(account_community_avatar_path),
        community_avatar_preset: preset }

      assert_response :unprocessable_entity
      assert_select '[role="alert"]', text: "Public avatar must be one of the available presets."
      assert_select 'input[name="community_avatar_preset"][value="moth"][checked]'
      assert_equal "moth", @user.reload.community_user&.community_avatar_preset
    end
  end

  test "guests cannot submit a Community avatar directly" do
    guest = Identity::UserGuest.create!
    sign_in(guest)
    get new_session_path

    patch account_community_avatar_path, params: { authenticity_token: page_csrf_token, community_avatar_preset: "raven" }

    assert_response :forbidden
    assert_not Community::CommunityUser.exists?(guest.id)
  end

  test "username conflicts return a localized form error and preserve the saved name" do
    other = registered_user("someone-else@example.test")
    Community::Membership::SetUpProfile.call(user_id: other.id, displayed_version: Community::CodeOfConduct.current.version, accepted: true)
    Community::Membership::ManageProfile.new(community_user: other.community_user).change_community_username(community_username: "Scream_Queen")
    Community::Membership::ManageProfile.new(community_user: @user.community_user).change_community_username(community_username: "Old_Name")
    sign_in(@user)
    get account_community_path(edit: "username")

    patch account_community_username_path, params: { authenticity_token: csrf_token(account_community_username_path),
      community_username: "scream_queen" }

    assert_response :unprocessable_entity
    assert_select '[role="alert"] li', text: username_error(:taken)
    assert_select 'input#community_username[value="scream_queen"][aria-invalid="true"]'
    assert_select "button[form='cancel-community-username']", text: I18n.t("identity.settings.cancel")
    assert_equal "Old_Name", @user.reload.community_user&.community_username
    assert_equal "Scream_Queen", other.reload.community_user&.community_username
  end

  test "invalid or reserved username submissions leave the saved name in place" do
    Community::Membership::ManageProfile.new(community_user: @user.community_user).change_community_username(community_username: "Old_Name")
    sign_in(@user)
    get account_community_path(edit: "username")

    [ [ "ab", :invalid ], [ "a" * 25, :invalid ], [ "has space", :invalid ], [ "Écho", :invalid ],
      [ { unexpected: "valid_name" }, :invalid ], [ "GlUtToN", :reserved ], [ nil, :invalid ] ].each do |name, error|
      patch account_community_username_path, params: { authenticity_token: csrf_token(account_community_username_path),
        community_username: name }

      assert_response :unprocessable_entity
      assert_select '[role="alert"] li', text: username_error(error)
      assert_equal "Old_Name", @user.reload.community_user&.community_username
    end

    [ "a_1", "a" * 24 ].each do |name|
      get account_community_path(edit: "username")
      patch account_community_username_path, params: { authenticity_token: csrf_token(account_community_username_path),
        community_username: name }
      assert_redirected_to account_community_path
      assert_equal name, @user.reload.community_user&.community_username
    end
  end

  test "account deletion rejects a request without a CSRF token" do
    sign_in(@user)
    get account_settings_path
    assert_response :success

    delete account_path
    assert_response :unprocessable_entity
    assert Identity::User.exists?(@user.id)
  end

  test "account deletion signs out a browser still holding a session cookie" do
    sign_in(@user)
    other = open_session
    other.cookies[:session_id] = cookies[:session_id]
    other.get account_settings_path
    assert_equal 200, other.response.status

    get account_settings_path
    assert_response :success
    delete account_path, params: { authenticity_token: csrf_token(account_path) }
    assert_redirected_to root_path
    assert_not Identity::User.exists?(@user.id)
    assert_not Identity::Session.exists?(user_id: @user.id)

    assert_no_difference [ "Identity::User.count", "Identity::Session.count" ] do
      other.get account_settings_path
      assert_equal 302, other.response.status
      assert_equal new_session_url, other.response.location
      assert_empty other.cookies[:session_id].to_s
    end
  end

  test "account deletion reports a retry and keeps the session when the log is unavailable" do
    previous_endpoint = ENV["ACCOUNT_DELETION_R2_ENDPOINT"]
    ENV["ACCOUNT_DELETION_R2_ENDPOINT"] = "invalid-endpoint"
    sign_in(@user)
    get account_settings_path

    delete account_path, params: { authenticity_token: csrf_token(account_path) }

    assert_redirected_to account_settings_path
    assert_equal I18n.t("identity.settings.deletion_log_unavailable"), flash[:alert]
    assert Identity::UserRegistered.exists?(@user.id)
    follow_redirect!
    assert_response :success
  ensure
    ENV["ACCOUNT_DELETION_R2_ENDPOINT"] = previous_endpoint
  end

  test "password change verifies the current password and revokes sessions" do
    sign_in(@user)
    other_session = Identity::Session.create!(user: @user)
    get account_settings_path
    token = csrf_token(account_password_path)

    patch account_password_path, params: { authenticity_token: token, current_password: "wrong",
      password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
    assert_response :unprocessable_entity
    assert @user.reload.authenticate(PASSWORD)
    assert Identity::Session.exists?(other_session.id)

    patch account_password_path, params: { authenticity_token: csrf_token(account_password_path), current_password: PASSWORD,
      password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
    assert_redirected_to new_session_path
    assert @user.reload.authenticate(NEW_PASSWORD)
    assert_not Identity::Session.exists?(user: @user)
  end

  test "only the requesting account can confirm a new email and the old address stays valid until then" do
    sign_in(@user)
    get account_settings_path
    assert_select ".account-settings-field p", "settings@example.test"

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post account_email_path, params: { authenticity_token: csrf_token(account_email_path),
        current_password: PASSWORD, email_address: " NEW@example.test " }
    end
    assert_redirected_to account_settings_path
    assert_equal "settings@example.test", @user.reload.email_address
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "new@example.test" ], mail.to
    link = URI.parse(mail.body.to_s.lines.find { |line| line.start_with?("https://") }.strip)

    sign_in(registered_user("another@example.test"))
    get link.request_uri
    assert_redirected_to account_settings_path

    sign_in(@user)
    get link.request_uri
    assert_response :success
    assert_equal "settings@example.test", @user.reload.email_address
    token = Nokogiri::HTML(response.body).at_css("input[name=token]")["value"]
    post confirm_account_email_path, params: { authenticity_token: csrf_token(confirm_account_email_path), token: }
    assert_redirected_to new_session_path
    assert_equal "new@example.test", @user.reload.email_address
    assert_not Identity::Session.exists?(user: @user)

    sign_in(@user)
    get link.request_uri
    assert_redirected_to account_settings_path
  end

  private

  def registered_user(email_address)
    Identity::UserRegistered.create!(email_address:, password: PASSWORD, password_confirmation: PASSWORD, email_confirmed_at: Time.current)
  end

  def sign_in(user)
    authentication = Identity::Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def csrf_token(action)
    Nokogiri::HTML(response.body).at_css("form[action='#{action}'] input[name=authenticity_token]")&.[]("value")
  end

  def page_csrf_token
    Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def username_error(type)
    attribute = I18n.t("activerecord.attributes.community/community_user.community_username")
    message = I18n.t("activerecord.errors.models.community/community_user.attributes.community_username.#{type}")
    "#{attribute} #{message}"
  end
end
