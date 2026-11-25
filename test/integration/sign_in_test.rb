require "test_helper"

class SignInTest < ActionDispatch::IntegrationTest
  setup do
    @forgery_protection = SessionsController.allow_forgery_protection
    SessionsController.allow_forgery_protection = true
    SessionsController::RATE_LIMIT_STORE.clear
    @user = Identity::UserRegistered.create!(email_address: "login@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
  end

  teardown do
    SessionsController.allow_forgery_protection = @forgery_protection
    SessionsController::RATE_LIMIT_STORE.clear
  end

  def token(client = self)
    Nokogiri::HTML(client.response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def sign_in(client = self, password: "a long password phrase")
    client.post session_path, params: { email_address: " LOGIN@example.test ", password: password, authenticity_token: token(client) }
  end

  test "sign in issues a persistent cookie and sign out revokes only that browser" do
    get new_session_path
    sign_in
    assert_response :see_other
    first = Identity::Session.last
    old_cookie = cookies[:session_id]
    header = Array(response.headers["set-cookie"]).join("\n").downcase
    assert_includes header, "expires="
    assert_includes header, "httponly"
    assert_includes header, "samesite=lax"
    assert_equal "no-store", response.headers["Cache-Control"]
    follow_redirect!
    get account_settings_path
    assert_select "main button", text: I18n.t("ui.log_out"), count: 1
    other = open_session
    other.get new_session_path
    sign_in(other)
    second = Identity::Session.last
    get new_session_path
    delete session_path, params: { authenticity_token: token }
    assert_response :see_other
    assert_nil Identity::Session.find_by(id: first.id)
    assert second.active?
    cookies[:session_id] = old_cookie
    get root_path
    assert_select "header button", text: I18n.t("ui.log_out"), count: 0
    get new_session_path
    delete session_path, params: { authenticity_token: token }
    assert_response :see_other
    assert_equal 1, Identity::Session.count
  end

  test "registered cookie is secure through production SSL middleware" do
    client = ActionDispatch::Integration::Session.new(ActionDispatch::SSL.new(Rails.application))
    client.https!
    client.get new_session_path
    sign_in(client)
    assert_equal 303, client.response.status
    assert_match(/; secure(?:;|$)/i, Array(client.response.headers["set-cookie"]).join("\n"))
  end

  test "invalid credentials have a generic error and preserve current identity" do
    get new_session_path
    sign_in
    existing = Identity::Session.last
    cookie = cookies[:session_id]
    assert_no_difference [ "Identity::Session.count", "Identity::User.count" ] do
      get new_session_path
      sign_in(password: "wrong password")
    end
    assert_response :unprocessable_entity
    assert_select '[role="alert"]', "Email or password is incorrect."
    assert_select 'input[type="password"][value]', count: 0
    assert_not_includes response.body, "wrong password"
    assert_equal cookie, cookies[:session_id]
    assert existing.active?
  end

  test "sign in switches this browser and does not revoke another browser" do
    get new_session_path
    sign_in
    previous = Identity::Session.last
    other = open_session
    other.get new_session_path
    sign_in(other)
    independent = Identity::Session.last
    get new_session_path
    sign_in
    assert_response :see_other
    assert_not previous.active?
    assert independent.active?
    assert Identity::Session.last.active?
    assert_equal 2, Identity::Session.count
  end

  test "sign in and sign out require CSRF and GET does not change sessions" do
    assert_no_difference "Identity::Session.count" do
      get new_session_path
      assert_select ".ui-page-back-above + main.ui-card.ui-narrow"
      assert_select ".ui-page-back-above a[href=?]", root_path, text: I18n.t("identity.entry.back")
      post session_path, params: { email_address: @user.email_address, password: "a long password phrase" }
      assert_response :unprocessable_entity
      delete session_path
      assert_response :unprocessable_entity
    end
  end

  test "rate limit rejects the eleventh attempt and expires after three minutes" do
    freeze_time do
      10.times do
        get new_session_path
        sign_in(password: "wrong")
        assert_response :unprocessable_entity
      end
      get new_session_path
      sign_in(password: "wrong")
      assert_response :too_many_requests
    end
    travel 181.seconds do
      get new_session_path
      sign_in
      assert_response :see_other
    end
  end

  test "failed prior-session revocation rolls back the issued replacement" do
    get new_session_path
    sign_in
    previous = Identity::Session.last
    cookie = cookies[:session_id]
    get new_session_path
    authenticity_token = token
    original = Identity::Session.method(:revoke)
    Identity::Session.define_singleton_method(:revoke) do |id:|
      original.call(id: id)
      raise ActiveRecord::ConnectionNotEstablished
    end
    assert_no_difference "Identity::Session.count" do
      assert_raises ActiveRecord::ConnectionNotEstablished do
        post session_path, params: { email_address: @user.email_address, password: "a long password phrase", authenticity_token: authenticity_token }
      end
    end
    assert_equal cookie, cookies[:session_id]
    assert previous.active?
  ensure
    Identity::Session.define_singleton_method(:revoke, original) if original
  end
end
