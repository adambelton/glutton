require "test_helper"

class PasswordRecoveryTest < ActionDispatch::IntegrationTest
  setup do
    @forgery = PasswordResetsController.allow_forgery_protection
    @session_forgery = SessionsController.allow_forgery_protection
    PasswordResetsController.allow_forgery_protection = true
    SessionsController.allow_forgery_protection = true
    PasswordResetsController::RATE_LIMIT_STORE.clear
    Identity::RegistrationRequests::RATE_LIMIT_STORE.clear
    SessionsController::RATE_LIMIT_STORE.clear
    @origin = ENV["APP_ORIGIN"]
    ENV["APP_ORIGIN"] = "https://glutton.example.test"
    @user = UserRegistered.create!(email_address: "recovery@example.test", password: "original password phrase",
      password_confirmation: "original password phrase", email_confirmed_at: Time.current)
    @reset_token = @user.password_reset_token
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    PasswordResetsController.allow_forgery_protection = @forgery
    SessionsController.allow_forgery_protection = @session_forgery
    PasswordResetsController::RATE_LIMIT_STORE.clear
    Identity::RegistrationRequests::RATE_LIMIT_STORE.clear
    SessionsController::RATE_LIMIT_STORE.clear
    ENV["APP_ORIGIN"] = @origin
  end

  def csrf(client = self)
    client.get new_session_path
    assert_equal 200, client.response.status
    Nokogiri::HTML(client.response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def sign_in(client = self, user: @user, password: "original password phrase")
    client.post session_path, params: { email_address: user.email_address, password:, authenticity_token: csrf(client) }
    assert_equal 303, client.response.status
  end

  def update_password(token: @reset_token, password: "replacement password phrase", authenticity_token: csrf)
    patch password_reset_path, params: { token:, password:, password_confirmation: password, authenticity_token: }
  end

  test "request form and neutral response for known and unknown accounts" do
    get new_session_path
    assert_select 'a[href="/password_reset/new"]', "Forgot your password?"
    get new_password_reset_path
    assert_response :success
    assert_select 'input[type="email"][required]'
    [ @user.email_address, "unknown@example.test" ].each do |email|
      post password_reset_path, params: { email_address: email, authenticity_token: csrf, return_to: "https://evil.test" }
      assert_redirected_to new_session_path
      follow_redirect!
      assert_select '[role="status"]', text: I18n.t("identity.recovery.requested"), count: 1
    end
    assert_equal 1, ActionMailer::Base.deliveries.count
    assert_equal 0, Session.count
  end

  test "GET HEAD and missing CSRF cannot change credentials or consume a link" do
    digest = @user.password_digest
    assert_no_difference [ "Session.count", "ActionMailer::Base.deliveries.count" ] do
      get edit_password_reset_path(token: @reset_token)
      assert_response :success
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_equal "no-referrer", response.headers["Referrer-Policy"]
      assert_select 'input[type="hidden"][name="token"]'
      head edit_password_reset_path(token: @reset_token)
      assert_response :success
      update_password(authenticity_token: nil)
      assert_response :unprocessable_entity
      post password_reset_path, params: { email_address: @user.email_address }
      assert_response :unprocessable_entity
    end
    assert_equal digest, @user.reload.password_digest
    assert_equal @user, UserRegistered.find_by_password_reset_token(@reset_token)
  end

  test "invalid input rerenders empty fields and success requires fresh sign in" do
    update_password(password: "leakpw")
    assert_response :unprocessable_entity
    assert_select '[role="alert"]'
    assert_select 'input[type="password"][value]', count: 0
    assert_not_includes response.body, "leakpw"
    update_password
    assert_redirected_to new_session_path
    assert_equal 0, Session.count
    follow_redirect!
    assert_select '[role="status"]', text: I18n.t("identity.recovery.completed"), count: 1
    update_password
    assert_response :unprocessable_entity
    post session_path, params: { email_address: @user.email_address, password: "original password phrase", authenticity_token: csrf }
    assert_response :unprocessable_entity
    sign_in(password: "replacement password phrase")
  end

  test "missing expired and tampered links have one unavailable result" do
    [ nil, "", "invalid" ].each do |token|
      get edit_password_reset_path(token:)
      assert_response :unprocessable_entity
      assert_select '[role="alert"]', text: I18n.t("identity.recovery.unavailable"), count: 1
    end
    travel 16.minutes do
      get edit_password_reset_path(token: @reset_token)
      assert_response :unprocessable_entity
    end
  end

  test "same account reset clears browser binding and every other session cookie" do
    sign_in
    other = open_session
    sign_in(other)
    old_cookie = other.cookies[:session_id]
    old_csrf = csrf
    update_password(authenticity_token: old_csrf)
    assert_response :see_other
    assert cookies[:session_id].blank?
    assert_equal 0, Session.count
    other.cookies[:session_id] = old_cookie
    other.get root_path
    assert_not_includes other.response.body, "Signed in"
    patch password_reset_path, params: { token: @user.reload.password_reset_token, password: "another password phrase",
      password_confirmation: "another password phrase", authenticity_token: old_csrf }
    assert_response :unprocessable_entity
    assert @user.reload.authenticate("replacement password phrase")
  end

  test "another registered browser conflicts and deleted browser fails explicitly" do
    other = UserRegistered.create!(email_address: "different@example.test", password: "original password phrase",
      password_confirmation: "original password phrase", email_confirmed_at: Time.current)
    sign_in(user: other)
    cookie = cookies[:session_id]
    get edit_password_reset_path(token: @reset_token)
    assert_response :conflict
    update_password
    assert_response :conflict
    assert_equal cookie, cookies[:session_id]
    assert @user.reload.authenticate("original password phrase")
    other.update_columns(type: "UserDeleted", email_address: nil, password_digest: nil, email_confirmed_at: nil)
    get new_password_reset_path
    assert_response :gone
  end

  test "unrelated guest and its pending registration survive reset without merging" do
    previous = HomeController.instance_method(:index)
    HomeController.define_method(:index) do
      ensure_guest_user!
      render plain: "guest"
    end
    post registration_path, params: { registration: { email_address: "guest-pending@example.test", password: "original password phrase",
      password_confirmation: "original password phrase" }, authenticity_token: csrf }
    assert_response :see_other
    get root_path
    guest_session = Session.last
    guest = guest_session.user
    pending = PendingRegistration.last
    assert_equal guest.id, pending.guest_user_id
    cookie = cookies[:session_id]
    update_password
    assert_response :see_other
    assert_equal cookie, cookies[:session_id]
    assert guest_session.active?
    assert_not (guest.reload).can_reset_password?
    assert PendingRegistration.exists?(pending.id)
    get registration_path
    assert_response :success
    assert_select "h1", I18n.t("identity.registration.pending_title")
    assert @user.reload.authenticate("replacement password phrase")
  ensure
    HomeController.define_method(:index, previous) if previous
  end

  test "request logs filter full token URLs credentials and email cache keys" do
    output = StringIO.new
    logger = ActiveSupport::Logger.new(output)
    original_logger = Rails.logger
    original_controller = ActionController::Base.logger
    original_dispatch = Rails.application.env_config["action_dispatch.logger"]
    Rails.logger = logger
    ActionController::Base.logger = logger
    Rails.application.env_config["action_dispatch.logger"] = logger
    get edit_password_reset_path(token: @reset_token)
    assert_response :success
    update_password(password: "private-password-marker")
    post password_reset_path, params: { email_address: @user.email_address, authenticity_token: csrf }
    post password_reset_path, params: { email_address: @user.email_address, authenticity_token: csrf }
    assert_response :too_many_requests
    [ @reset_token, @user.email_address, "private-password-marker" ].each { |marker| refute_includes output.string, marker }
    assert_includes output.string, "[FILTERED]"
    assert_not_includes cookies[:session_id].to_s, @reset_token
    assert_not_includes cookies[Rails.application.config.session_options[:key]].to_s, @reset_token
  ensure
    Rails.logger = original_logger
    ActionController::Base.logger = original_controller
    Rails.application.env_config["action_dispatch.logger"] = original_dispatch
  end

  test "trusted origin ignores request host and transport failure is retryable" do
    post password_reset_path, params: { email_address: @user.email_address, authenticity_token: csrf,
      return_to: "https://evil.test", origin: "https://evil.test" }, headers: { "HOST" => "evil.test" }
    assert_response :see_other
    assert_includes ActionMailer::Base.deliveries.last.text_part.body.decoded, "https://glutton.example.test/"
    assert_not_includes ActionMailer::Base.deliveries.last.text_part.body.decoded, "evil.test"
    PasswordResetsController::RATE_LIMIT_STORE.clear
    original = Identity::AccountMailer.method(:password_reset)
    Identity::AccountMailer.define_singleton_method(:password_reset) { |**| raise Net::SMTPFatalError, "private-provider-marker" }
    post password_reset_path, params: { email_address: @user.email_address, authenticity_token: csrf }
    assert_response :service_unavailable
    assert_select '[role="alert"]', I18n.t("identity.recovery.delivery_failed")
    assert_not_includes response.body, "private-provider-marker"
  ensure
    Identity::AccountMailer.define_singleton_method(:password_reset, original) if original
  end

  test "email fingerprint cooldown includes unknown and normalized addresses" do
    freeze_time do
      post password_reset_path, params: { email_address: "UNKNOWN@example.test", authenticity_token: csrf }
      assert_response :see_other
      post password_reset_path, params: { email_address: " unknown@example.test ", authenticity_token: csrf }
      assert_response :too_many_requests
      travel 60.seconds
      post password_reset_path, params: { email_address: "unknown@example.test", authenticity_token: csrf }
      assert_response :see_other
    end
    assert_equal 0, ActionMailer::Base.deliveries.count
  end

  test "request IP budget and update IP budget block before mutation and expire" do
    freeze_time do
      10.times do |index|
        post password_reset_path, params: { email_address: "unknown#{index}@example.test", authenticity_token: csrf }
        assert_response :see_other
        update_password(token: "invalid")
        assert_response :unprocessable_entity
      end
      post password_reset_path, params: { email_address: @user.email_address, authenticity_token: csrf }
      assert_response :too_many_requests
      update_password
      assert_response :too_many_requests
      assert @user.reload.authenticate("original password phrase")
      assert_equal 0, ActionMailer::Base.deliveries.count
      travel 180.seconds
      update_password
      assert_response :see_other
    end
  end
end
