require "test_helper"

class Identity::GuestSessionRequestsTest < ActionController::TestCase
  tests GuestSessionsController

  setup { GuestSessionsController::RATE_LIMIT_STORE.clear }

  test "explicit guest entry rotates browser session and repeated entry reuses it" do
    assert_difference [ "Identity::UserGuest.count", "Identity::Session.count" ], 1 do
      post :create, session: { marker: "old session" }
    end
    assert_response :see_other
    assert_redirected_to new_rating_path
    assert_nil session[:marker]

    assert_no_difference [ "Identity::UserGuest.count", "Identity::Session.count" ] do
      post :create
    end
    assert_redirected_to new_rating_path
  end

  test "failed session creation rolls back the guest and sets no identity cookie" do
    with_failure(Identity::Session, :create!, ActiveRecord::ConnectionNotEstablished.new) do
      assert_no_difference [ "Identity::User.count", "Identity::Session.count" ] do
        assert_raises(ActiveRecord::ConnectionNotEstablished) { post :create }
      end
    end
    assert_nil cookies[:session_id]
  end

  test "identity lookup errors propagate without replacing the existing session" do
    authentication = Identity::Session.create!(user: Identity::UserGuest.create!)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: authentication.user_id } }
    cookies[:session_id] = jar[:session_id]

    with_failure(Identity::Session, :resume, ActiveRecord::ConnectionNotEstablished.new) do
      assert_no_difference [ "Identity::User.count", "Identity::Session.count" ] do
        assert_raises(ActiveRecord::ConnectionNotEstablished) { post :create }
      end
    end
    assert authentication.active?
    assert_equal jar[:session_id], cookies[:session_id]
  end

  test "attachment failure rolls back the new guest and retains the pending registration" do
    pending = prepare_registration
    with_failure(Identity::AttachRegistration, :call, Identity::RegistrationConflict.new) do
      assert_no_difference [ "Identity::User.count", "Identity::Session.count" ] do
        assert_raises(Identity::RegistrationConflict) { post :create, session: { pending_registration_id: pending.id } }
      end
    end
    assert_nil pending.reload.guest_user_id
    assert_equal pending.id, session[:pending_registration_id]
    assert_nil cookies[:session_id]
  end

  test "guest entry clears expired pending state with feedback" do
    pending = prepare_registration
    travel_to pending.expires_at + 1.second do
      assert_difference "Identity::UserGuest.count", 1 do
        post :create, session: { pending_registration_id: pending.id }
      end
      assert_redirected_to new_rating_path
      assert_nil session[:pending_registration_id]
      assert_nil pending.reload.guest_user_id
      assert_equal I18n.t("identity.registration.unavailable"), flash[:alert]
    end
  end

  private

  def prepare_registration
    Identity::PrepareRegistration.call(email_address: "pending@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase")
  end

  def with_failure(model, method_name, error)
    original = model.method(method_name)
    owned = model.singleton_class.instance_methods(false).include?(method_name)
    model.define_singleton_method(method_name) { |*| raise error }
    yield
  ensure
    model.singleton_class.remove_method(method_name)
    model.define_singleton_method(method_name, original) if owned
  end
end

class Identity::LandingSessionRequestsTest < ActionController::TestCase
  tests LandingController

  test "legacy user id cannot sign a browser in or create an account or session" do
    user = Identity::UserRegistered.create!(email_address: "old@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    assert_no_difference [ "Identity::User.count", "Identity::Session.count" ] do
      get :show, session: { user_id: user.id }
    end
    assert_response :success
    assert_select "h1", I18n.t("identity.entry.title")
  end

  test "a valid signed binding redirects to the guest destination" do
    authentication = Identity::Session.create!(user: Identity::UserGuest.create!)
    set_identity_cookie(id: authentication.id, user_id: authentication.user_id)
    get :show
    assert_redirected_to new_rating_path
  end

  test "a signed binding with malformed contents cannot sign a browser in" do
    set_identity_cookie("malformed")
    assert_anonymous_landing
  end

  test "a signed binding for the wrong existing user cannot sign a browser in" do
    authentication = Identity::Session.create!(user: Identity::UserGuest.create!)
    set_identity_cookie(id: authentication.id, user_id: Identity::UserGuest.create!.id)
    assert_anonymous_landing
  end

  private

  def set_identity_cookie(binding)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: binding }
    cookies[:session_id] = jar[:session_id]
  end

  def assert_anonymous_landing
    assert_no_difference [ "Identity::User.count", "Identity::Session.count" ] do
      get :show
    end
    assert_response :success
    assert_select "h1", I18n.t("identity.entry.title")
  end
end

class Identity::PendingRegistrationRequestsTest < ActionController::TestCase
  tests RegistrationsController

  test "an anonymous browser can see its unattached request but loses access once it is linked" do
    pending = Identity::PrepareRegistration.call(email_address: "pending@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase")
    get :show, session: { pending_registration_id: pending.id }
    assert_response :success
    assert_select "p", I18n.t("identity.registration.verify_required")

    pending.attach_to!(user: Identity::UserGuest.create!)
    get :show
    assert_response :unprocessable_entity
    assert_nil session[:pending_registration_id]
    assert_select '[role="alert"]', text: I18n.t("identity.registration.unavailable")
  end
end
