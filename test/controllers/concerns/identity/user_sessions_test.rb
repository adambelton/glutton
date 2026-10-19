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
    session[:user_id] = RegisteredUser.create!(email_address: "old@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current).id
    assert_no_difference [ "User.count", "Session.count" ] do
      assert_nil @controller.send(:current_user)
    end
  end

  test "guest creation resets browser session and is reused within request" do
    session[:marker] = "old session"
    user = nil
    assert_difference [ "GuestUser.count", "Session.count" ], 1 do
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
    guest = GuestUser.create!
    authentication = Session.create!(user: guest)
    cookies.signed[:session_id] = { id: authentication.id, user_id: guest.id + 1 }
    assert_nil @controller.send(:current_user)
  end

  test "database lookup errors propagate rather than replacing an identity" do
    authentication = bind(GuestUser.create!)
    @controller.remove_instance_variable(:@current_user)
    with_failure(User, :find_by, ActiveRecord::ConnectionNotEstablished.new) do
      assert_raises ActiveRecord::ConnectionNotEstablished do
        @controller.send(:ensure_guest_user!)
      end
    end
    assert_equal authentication.id, @controller.send(:identity_payload)["id"]
  end

  private

  def with_failure(model, method_name, error)
    model.define_singleton_method(method_name) { |*| raise error }
    yield
  ensure
    model.singleton_class.remove_method(method_name)
  end
end
