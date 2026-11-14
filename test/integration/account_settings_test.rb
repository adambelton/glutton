require "test_helper"

class AccountSettingsTest < ActionDispatch::IntegrationTest
  PASSWORD = "a long test password"
  NEW_PASSWORD = "a different long password"

  setup do
    @forgery_protection = AccountSettingsController.allow_forgery_protection
    AccountSettingsController.allow_forgery_protection = true
    AccountSettingsController::RATE_LIMIT_STORE.clear
    @previous_origin = ENV["APP_ORIGIN"]
    ENV["APP_ORIGIN"] = "https://glutton.example"
    @user = registered_user("settings@example.test")
  end

  teardown do
    ENV["APP_ORIGIN"] = @previous_origin
    AccountSettingsController.allow_forgery_protection = @forgery_protection
    AccountSettingsController::RATE_LIMIT_STORE.clear
  end

  test "account settings reject signed-out viewers and guests" do
    get account_settings_path
    assert_redirected_to new_session_path
    sign_in(Identity::UserGuest.create!)
    get account_settings_path
    assert_response :forbidden
  end

  test "account deletion rejects a request without a CSRF token" do
    sign_in(@user)
    get account_settings_path
    assert_response :success

    delete account_path
    assert_response :unprocessable_entity
    assert Identity::User.exists?(@user.id)
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
end
