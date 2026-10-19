require "test_helper"

class SignInTest < ActionDispatch::IntegrationTest
  setup do
    @forgery_protection = SessionsController.allow_forgery_protection
    SessionsController.allow_forgery_protection = true
    SessionsController::RATE_LIMIT_STORE.clear
    @user = RegisteredUser.create!(email_address: "login@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
  end

  teardown do
    SessionsController.allow_forgery_protection = @forgery_protection
    SessionsController::RATE_LIMIT_STORE.clear
  end

  def token(client = self)
    client.get new_session_path
    assert_equal 200, client.response.status
    Nokogiri::HTML(client.response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def sign_in(client = self, password: "a long password phrase")
    client.post session_path, params: { email_address: " LOGIN@example.test ", password: password, authenticity_token: token(client) }
  end

  test "sign in issues a persistent cookie and sign out revokes only that browser" do
    sign_in
    assert_response :see_other
    first = Session.last
    old_cookie = cookies[:session_id]
    header = Array(response.headers["set-cookie"]).join("\n").downcase
    assert_includes header, "expires="
    assert_includes header, "httponly"
    assert_includes header, "samesite=lax"
    assert_equal "no-store", response.headers["Cache-Control"]
    other = open_session
    sign_in(other)
    second = Session.last
    delete session_path, params: { authenticity_token: token }
    assert_response :see_other
    assert_nil Session.find_by(id: first.id)
    assert second.active?
    cookies[:session_id] = old_cookie
    get root_path
    assert_select "p", text: "Signed in", count: 0
    delete session_path, params: { authenticity_token: token }
    assert_response :see_other
    assert_equal 1, Session.count
  end

  test "registered cookie is secure through production SSL middleware" do
    client = ActionDispatch::Integration::Session.new(ActionDispatch::SSL.new(Rails.application))
    client.https!
    sign_in(client)
    assert_equal 303, client.response.status
    assert_match(/; secure(?:;|$)/i, Array(client.response.headers["set-cookie"]).join("\n"))
  end

  test "invalid credentials have a generic error and preserve current identity" do
    sign_in
    existing = Session.last
    cookie = cookies[:session_id]
    assert_no_difference [ "Session.count", "User.count" ] do
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
    sign_in
    previous = Session.last
    other = open_session
    sign_in(other)
    independent = Session.last
    sign_in
    assert_response :see_other
    assert_not previous.active?
    assert independent.active?
    assert Session.last.active?
    assert_equal 2, Session.count
  end

  test "sign in and sign out require CSRF and GET does not change sessions" do
    assert_no_difference "Session.count" do
      get new_session_path
      post session_path, params: { email_address: @user.email_address, password: "a long password phrase" }
      assert_response :unprocessable_entity
      delete session_path
      assert_response :unprocessable_entity
    end
  end

  test "rate limit rejects the eleventh attempt and expires after three minutes" do
    freeze_time do
      10.times do
        sign_in(password: "wrong")
        assert_response :unprocessable_entity
      end
      sign_in(password: "wrong")
      assert_response :too_many_requests
    end
    travel 181.seconds do
      sign_in
      assert_response :see_other
    end
  end

  test "deleted revoked binding still reports deletion but can explicitly sign out or sign in" do
    sign_in
    authentication = Session.last
    other = open_session
    other.cookies[:session_id] = cookies[:session_id]
    @user.update_columns(type: "DeletedUser", email_address: nil, password_digest: nil, email_confirmed_at: nil)
    Session.revoke(id: authentication.id)
    [ self, other ].each do |client|
      2.times do
        client.get root_path
        assert_equal 410, client.response.status
        assert_includes client.response.body, "This account has been deleted."
      end
    end
    assert_select 'form[action="/session"] input[name="_method"][value="delete"]'
    delete session_path, params: { authenticity_token: token }
    get root_path
    assert_response :success
    replacement = RegisteredUser.create!(email_address: "other@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    other.post session_path, params: { email_address: replacement.email_address, password: "a long password phrase", authenticity_token: token(other) }
    assert_equal 303, other.response.status
    other.get root_path
    assert_equal 200, other.response.status
  end

  test "failed prior-session revocation rolls back the issued replacement" do
    sign_in
    previous = Session.last
    cookie = cookies[:session_id]
    authenticity_token = token
    original = Session.method(:revoke)
    Session.define_singleton_method(:revoke) do |id:|
      original.call(id: id)
      raise ActiveRecord::ConnectionNotEstablished
    end
    assert_no_difference "Session.count" do
      assert_raises ActiveRecord::ConnectionNotEstablished do
        post session_path, params: { email_address: @user.email_address, password: "a long password phrase", authenticity_token: authenticity_token }
      end
    end
    assert_equal cookie, cookies[:session_id]
    assert previous.active?
  ensure
    Session.define_singleton_method(:revoke, original) if original
  end
end
