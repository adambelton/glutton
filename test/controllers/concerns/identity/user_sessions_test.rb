require "test_helper"

class UserSessionsHostController < ActionController::Base
  include Identity::UserSessions
end

class Identity::UserSessionsTest < ActionController::TestCase
  tests UserSessionsHostController

  def bind(user)
    authentication = Session.create!(user: user)
    @controller.send(:bind_session, authentication)
    authentication
  end

  test "lookup without identity and legacy user id create no account or session" do
    session[:user_id] = UserRegistered.create!(email_address: "old@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current).id
    assert_no_difference [ "User.count", "Session.count" ] do
      assert_nil @controller.send(:current_user)
    end
  end

  test "guest creation resets browser session and is reused within request" do
    session[:marker] = "old session"
    user = nil
    assert_difference [ "UserGuest.count", "Session.count" ], 1 do
      user = @controller.send(:ensure_guest_user!)
      assert_same user, @controller.send(:ensure_guest_user!)
    end
    assert_equal user.id, @controller.send(:bound_session).user_id
    assert_nil session[:marker]
    assert_nil session[:user_id]
  end

  test "failed session creation rolls back the new guest and binds nothing" do
    with_failure(Session, :create!, ActiveRecord::ConnectionNotEstablished.new) do
      assert_no_difference [ "User.count", "Session.count" ] do
        assert_raises ActiveRecord::ConnectionNotEstablished do
          @controller.send(:ensure_guest_user!)
        end
      end
    end
    assert_nil @controller.send(:identity_payload)
  end

  test "malformed signed cookie and mismatched references do not grant access" do
    guest = UserGuest.create!
    authentication = Session.create!(user: guest)
    cookies.signed[:session_id] = { id: authentication.id, user_id: guest.id + 1 }
    assert_nil @controller.send(:current_user)
  end

  test "database lookup errors propagate rather than replacing an identity" do
    authentication = bind(UserGuest.create!)
    @controller.remove_instance_variable(:@current_user)
    with_failure(User, :find_by, ActiveRecord::ConnectionNotEstablished.new) do
      assert_raises ActiveRecord::ConnectionNotEstablished do
        @controller.send(:ensure_guest_user!)
      end
    end
    assert_equal authentication.id, @controller.send(:identity_payload)["id"]
  end

  test "attachment failure rolls back new guest and session without losing pending state" do
    pending = Identity::PrepareRegistration.call(email_address: "pending@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase")
    session[:pending_registration_id] = pending.id
    with_failure(Identity::AttachRegistration, :call, Identity::RegistrationConflict.new) do
      assert_no_difference [ "User.count", "Session.count" ] do
        assert_raises(Identity::RegistrationConflict) { @controller.send(:ensure_guest_user!) }
      end
    end
    assert_nil pending.reload.guest_user_id
    assert_equal pending.id, session[:pending_registration_id]
  end

  test "expired pending state is cleared before first guest action with explicit feedback" do
    freeze_time
    pending = Identity::PrepareRegistration.call(email_address: "pending@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase")
    session[:pending_registration_id] = pending.id
    travel PendingRegistration::EXPIRY_DURATION
    guest = @controller.send(:ensure_guest_user!)
    assert_not (guest).can_reset_password?
    assert_nil session[:pending_registration_id]
    assert_nil pending.reload.guest_user_id
    assert_equal I18n.t("identity.registration.unavailable"), flash[:alert]
  end

  test "anonymous browser sees unattached registration but cannot access a linked request" do
    pending = Identity::PrepareRegistration.call(email_address: "pending@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase")
    session[:pending_registration_id] = pending.id
    assert_equal pending, @controller.send(:current_pending_registration)

    pending.attach_to!(user: UserGuest.create!)
    assert_nil @controller.send(:current_pending_registration)
    assert_nil session[:pending_registration_id]
    assert_equal I18n.t("identity.registration.unavailable"), flash[:alert]
  end

  private

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
