require "test_helper"
require "uri"
require "stringio"

class RegistrationActivityProbeController < ApplicationController
  def create
    render json: { id: ensure_guest_user!.id }
  end
end

class RegistrationFlowTest < ActionDispatch::IntegrationTest
  setup do
    @origin = ENV["APP_ORIGIN"]
    ENV["APP_ORIGIN"] = "https://glutton.example.test"
    @controllers = [ RegistrationsController, RegistrationEmailsController, RegistrationConfirmationsController,
      SessionsController, RegistrationActivityProbeController ]
    @forgery = @controllers.to_h { |controller| [ controller, controller.allow_forgery_protection ] }
    @controllers.each { |controller| controller.allow_forgery_protection = true }
    Identity::RegistrationRequests::RATE_LIMIT_STORE.clear
    SessionsController::RATE_LIMIT_STORE.clear
    ActionMailer::Base.deliveries.clear
    Rails.application.routes.draw do
      root "home#index"
      get "/rating/new", to: "ratings#new", as: :new_rating
      resource :password_reset, only: [ :new, :create, :edit, :update ]
      resource :session, only: [ :new, :create, :destroy ]
      resource :registration, only: [ :new, :create, :show ]
      resource :registration_email, only: :create
      resource :registration_confirmation, only: [ :show, :create ]
      post "/registration-activity-probe", to: "registration_activity_probe#create"
    end
  end

  teardown do
    ENV["APP_ORIGIN"] = @origin
    @forgery.each { |controller, enabled| controller.allow_forgery_protection = enabled }
    Identity::RegistrationRequests::RATE_LIMIT_STORE.clear
    SessionsController::RATE_LIMIT_STORE.clear
    Rails.application.reload_routes!
  end

  def csrf(client = self, path: new_session_path)
    client.get path
    assert_equal 200, client.response.status
    Nokogiri::HTML(client.response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def signup(client = self, **attributes)
    credentials = { email_address: "reader@example.test", password: "a long password phrase", password_confirmation: "a long password phrase" }.merge(attributes)
    client.post registration_path, params: { registration: credentials, authenticity_token: csrf(client) }
  end

  def email_token
    text = ActionMailer::Base.deliveries.last.text_part.body.decoded
    url = URI.parse(text.lines.find { |line| line.start_with?("https://") }.strip)
    assert_equal "glutton.example.test", url.host
    URI.decode_www_form(url.query).to_h.fetch("token")
  end

  def confirm(client = self, token: email_token)
    client.post registration_confirmation_path, params: { token:, authenticity_token: csrf(client) }
  end

  def guest(client = self)
    client.post "/registration-activity-probe", params: { authenticity_token: csrf(client) }
    assert_equal 200, client.response.status
    User.find(JSON.parse(client.response.body).fetch("id"))
  end

  test "direct signup sends an exact trusted link without creating user until explicit confirmation" do
    assert_no_difference [ "User.count", "Session.count" ] do
      assert_difference "PendingRegistration.count", 1 do
        signup(email_address: " Reader@Example.TEST ", guest_user_id: 999, id: 999)
      end
    end
    assert_response :see_other
    registration = PendingRegistration.last
    assert_nil registration.guest_user_id
    assert_equal [ "reader@example.test" ], ActionMailer::Base.deliveries.last.to
    token = email_token
    get registration_confirmation_path, params: { token: }
    assert_response :success
    assert_select 'form[action="/registration_confirmation"] input[name="token"][type="hidden"]'
    assert_select 'form[action="/registration_confirmation"] input[type="submit"]'
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_equal 0, UserRegistered.count
    head registration_confirmation_path, params: { token: }
    assert_response :success
    assert_equal 0, UserRegistered.count
    confirm(token:)
    assert_response :see_other
    assert (Session.last.user).can_reset_password?
    assert_not PendingRegistration.exists?(registration.id)
    header = Array(response.headers["set-cookie"]).join("\n").downcase
    %w[expires= httponly samesite=lax].each { |value| assert_includes header, value }
    follow_redirect!
    assert_select '[role="status"]', text: I18n.t("identity.registration.completed")
    assert_select "aside", count: 0
  end

  test "cleaned guest cookies and pending links cannot restore identities" do
    freeze_time
    created = guest
    signup
    registration = PendingRegistration.last
    confirmation_token = email_token
    old_cookie = cookies[:session_id]
    travel UserGuest::EXPIRY_DURATION
    assert_equal({ guests_deleted: 1, pending_registrations_deleted: 1 }, Identity::CleanupExpiredAccounts.call)
    cookies[:session_id] = old_cookie
    get registration_confirmation_path(token: confirmation_token)
    assert_response :unprocessable_entity
    get registration_path
    assert_response :unprocessable_entity
    replacement = guest
    assert_not_equal created.id, replacement.id
    assert_nil User.find_by(id: created.id)
    assert_nil PendingRegistration.find_by(id: registration.id)
  end

  test "first activity after signup retains pending reference and issued link claims the same guest" do
    signup
    registration = PendingRegistration.last
    token = email_token
    created = guest
    assert_equal created.id, registration.reload.guest_user_id
    get root_path
    assert_response :success
    assert_select 'aside[role="status"]', text: /#{Regexp.escape(I18n.t("identity.registration.guest_temporary"))}/
    assert_select "aside", text: /#{Regexp.escape(I18n.l(registration.expires_at, format: :registration))}/
    get registration_path
    assert_response :success
    assert_select "aside", count: 0
    assert_select "p", text: I18n.t("identity.registration.verify_required"), count: 1
    old_session = Session.last
    confirm(token:)
    assert_response :see_other
    assert_equal created.id, Session.last.user_id
    assert_not old_session.active?
    assert (User.find(created.id)).can_reset_password?
  end

  test "existing guest signup and cross browser confirmation preserve that guest only" do
    created = guest
    signup
    registration = PendingRegistration.last
    assert_equal created.id, registration.guest_user_id
    token = email_token
    other = open_session
    confirm(other, token:)
    assert_equal 303, other.response.status
    assert_equal created.id, Session.last.user_id
    assert (User.find(created.id)).can_reset_password?
  end

  test "signup in another browser confirms with the current guest only on POST" do
    signup
    registration = PendingRegistration.last
    token = email_token
    other = open_session
    created = guest(other)
    previous_session = Session.find_by!(user_id: created.id)

    assert_no_difference [ "User.count", "Session.count", "PendingRegistration.count" ] do
      other.get registration_confirmation_path, params: { token: }
      assert_equal 200, other.response.status
    end
    assert_nil registration.reload.guest_user_id
    assert_not User.find(created.id).can_reset_password?

    confirm(other, token:)
    assert_equal 303, other.response.status
    assert_not previous_session.active?
    assert_equal created.id, Session.last.user_id
    assert User.find(created.id).can_reset_password?
    assert_not PendingRegistration.exists?(registration.id)
  end

  test "invalid submission keeps previous credentials and never echoes password fields" do
    signup
    previous = PendingRegistration.last
    attributes = previous.slice(:id, :guest_user_id, :email_address, :password_digest, :created_at)
    signup(password: "tiny", password_confirmation: "tiny")
    assert_response :unprocessable_entity
    assert_equal attributes, previous.reload.slice(:id, :guest_user_id, :email_address, :password_digest, :created_at)
    assert_select 'input[type="password"][value]', count: 0
    assert_not_includes response.body, "tiny"
    assert_select '[role="alert"]'
    get registration_path
    assert_response :success
  end

  test "valid replacement invalidates the previous direct request and old link" do
    signup
    old = PendingRegistration.last
    token = email_token
    signup(email_address: "new@example.test")
    assert_response :see_other
    assert_not PendingRegistration.exists?(old.id)
    assert_equal 1, PendingRegistration.count
    confirm(token:)
    assert_response :unprocessable_entity
    assert_equal 0, UserRegistered.count
  end

  test "resend enforces a minute interval five attempts and preserves expiry" do
    freeze_time
    signup
    registration = PendingRegistration.last
    created_at = registration.created_at
    post registration_email_path, params: { authenticity_token: csrf }
    assert_response :too_many_requests
    assert_equal 1, ActionMailer::Base.deliveries.count
    4.times do
      travel 60.seconds
      post registration_email_path, params: { authenticity_token: csrf }
      assert_response :see_other
    end
    travel 60.seconds
    post registration_email_path, params: { authenticity_token: csrf }
    assert_response :too_many_requests
    assert_equal 5, registration.reload.confirmation_delivery_attempts
    assert_equal 5, ActionMailer::Base.deliveries.count
    assert_equal created_at, registration.created_at
  end

  test "CSRF protects submission resend and completion" do
    get new_registration_path
    assert_no_difference [ "PendingRegistration.count", "User.count", "Session.count" ] do
      post registration_path, params: { registration: { email_address: "reader@example.test" } }
      assert_response :unprocessable_entity
    end
    signup
    token = email_token
    assert_no_difference [ "User.count", "Session.count", "ActionMailer::Base.deliveries.count" ] do
      post registration_email_path
      assert_response :unprocessable_entity
      post registration_confirmation_path, params: { token:, authenticity_token: "invalid" }
      assert_response :unprocessable_entity
    end
  end

  test "a different linked guest and registered identity cannot switch by confirmation" do
    linked_guest = guest
    signup
    registration = PendingRegistration.last
    assert_equal linked_guest.id, registration.guest_user_id
    token = email_token
    other = open_session
    unrelated = guest(other)
    other.get registration_confirmation_path, params: { token: }
    assert_equal 409, other.response.status
    confirm(other, token:)
    assert_equal 409, other.response.status
    assert_not (User.find(unrelated.id)).can_reset_password?
    assert_equal linked_guest.id, registration.reload.guest_user_id
    assert_equal 1, PendingRegistration.count
    user = UserRegistered.create!(email_address: "existing@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    other.post session_path, params: { email_address: user.email_address, password: "a long password phrase", authenticity_token: csrf(other) }
    other.get registration_confirmation_path, params: { token: }
    assert_equal 409, other.response.status
    confirm(other, token:)
    assert_equal 409, other.response.status
    assert_equal user.id, Session.last.user_id
    assert_equal 1, PendingRegistration.count
    other.get new_registration_path
    assert_equal 409, other.response.status
  end

  test "expired pending reminder becomes explicit unavailable notice without reviving request" do
    freeze_time
    signup
    registration = PendingRegistration.last
    token = email_token
    travel PendingRegistration::EXPIRY_DURATION
    get root_path
    assert_select '[role="alert"]', text: I18n.t("identity.registration.unavailable")
    assert_select "aside", count: 0
    confirm(token:)
    assert_response :unprocessable_entity
    assert PendingRegistration.exists?(registration.id)
    assert_equal 0, User.count
  end

  test "already registered email is rejected without pending creation or another email" do
    existing = UserRegistered.create!(email_address: "reader@example.test", password: "existing password phrase",
      password_confirmation: "existing password phrase", email_confirmed_at: Time.current)
    assert_no_difference [ "PendingRegistration.count", "Session.count", "ActionMailer::Base.deliveries.count" ] do
      signup(email_address: " READER@Example.TEST ")
      assert_response :unprocessable_entity
    end
    assert_select '[role="alert"]', text: /already registered/
    assert_select 'a[href="/session/new"]'
    assert_equal existing, User.sole
  end

  test "signup and resend share the IP request budget before database mutation" do
    signup
    9.times do
      post registration_email_path, params: { authenticity_token: csrf }
      assert_response :too_many_requests
    end
    assert_no_difference "PendingRegistration.count" do
      signup(email_address: "another@example.test")
      assert_response :too_many_requests
    end
    assert_equal 1, ActionMailer::Base.deliveries.count
  end

  test "known delivery failure is honest and keeps a retryable pending request" do
    Identity::AccountMailer.define_singleton_method(:confirmation) { |**| raise Net::SMTPFatalError, "private SMTP detail" }
    signup
    assert_response :see_other
    record = PendingRegistration.last
    assert_equal 1, record.confirmation_delivery_attempts
    assert_equal 0, User.count
    assert_equal 0, ActionMailer::Base.deliveries.count
    follow_redirect!
    assert_select '[role="alert"]', text: I18n.t("identity.registration.delivery_failed")
    assert_not_includes response.body, "private SMTP detail"
    assert_not_includes response.body, I18n.t("identity.registration.accepted")
    get registration_path
    assert_response :success
  ensure
    Identity::AccountMailer.singleton_class.remove_method(:confirmation)
  end

  test "confirmation IP budget rejects before account or session mutation" do
    authenticity_token = csrf
    10.times do
      post registration_confirmation_path, params: { token: "invalid", authenticity_token: }
      assert_response :unprocessable_entity
    end
    signup
    token = email_token
    assert_no_difference [ "User.count", "Session.count", "PendingRegistration.count" ] do
      confirm(token:)
      assert_response :too_many_requests
    end
  end

  test "trusted origin ignores hostile Host and redirect parameters" do
    authenticity_token = csrf
    post registration_path, params: { authenticity_token:, return_to: "https://evil.example", registration: {
      email_address: "reader@example.test", password: "a long password phrase", password_confirmation: "a long password phrase"
    } }, headers: { "Host" => "evil.example" }
    assert_response :see_other
    email_token
    refute_includes ActionMailer::Base.deliveries.last.text_part.body.decoded, "evil.example"
  end

  test "another browser cannot resend or select someone else's pending request" do
    signup
    record = PendingRegistration.last
    other = open_session
    assert_no_difference "ActionMailer::Base.deliveries.count" do
      other.post registration_email_path, params: { pending_registration_id: record.id, authenticity_token: csrf(other) }
      assert_equal 422, other.response.status
    end
    assert_equal 1, record.reload.confirmation_delivery_attempts
  end

  test "deleted browser identity retains its explicit failure even with pending state" do
    created = guest
    signup
    created.update_columns(type: "UserDeleted")
    get registration_path
    assert_response :gone
    get root_path
    assert_response :gone
    assert_select "h1", text: I18n.t("identity.sessions.deleted_title")
  end

  test "confirmation rotates CSRF state and produces secure cookies under SSL middleware" do
    signup
    token = email_token
    old_csrf = csrf
    confirm(token:)
    assert_response :see_other
    delete session_path, params: { authenticity_token: old_csrf }
    assert_response :unprocessable_entity
    assert Session.last.active?
    registration = Identity::PrepareRegistration.call(email_address: "secure@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase")
    token = Identity::RegistrationConfirmation.token_for(pending_registration_id: registration.id)
    secure = ActionDispatch::Integration::Session.new(ActionDispatch::SSL.new(Rails.application))
    secure.https!
    confirm(secure, token:)
    assert_equal 303, secure.response.status
    assert_match(/; secure(?:;|$)/i, Array(secure.response.headers["set-cookie"]).join("\n"))
  end

  test "routine request logs filter tokens addresses and passwords including GET URLs" do
    output = StringIO.new
    logger = ActiveSupport::Logger.new(output)
    original_logger = Rails.logger
    original_controller = ActionController::Base.logger
    original_dispatch = Rails.application.env_config["action_dispatch.logger"]
    Rails.logger = logger
    ActionController::Base.logger = logger
    Rails.application.env_config["action_dispatch.logger"] = logger
    signup(email_address: "private-reader@example.test", password: "private-password-marker", password_confirmation: "private-password-marker")
    token = email_token
    get registration_confirmation_path, params: { token: }
    assert_response :success
    [ token, "private-reader@example.test", "private-password-marker" ].each { |marker| refute_includes output.string, marker }
    assert_includes output.string, "[FILTERED]"
  ensure
    Rails.logger = original_logger
    ActionController::Base.logger = original_controller
    Rails.application.env_config["action_dispatch.logger"] = original_dispatch
  end

  test "signout clears pending browser state but leaves the request untouched" do
    signup
    record = PendingRegistration.last
    delete session_path, params: { authenticity_token: csrf }
    assert_response :see_other
    get registration_path
    assert_response :unprocessable_entity
    assert PendingRegistration.exists?(record.id)
  end
end
