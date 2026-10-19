require "test_helper"

class UserSessionsControllerTest < ActionController::TestCase
  tests ApplicationController

  test "lookup without identity does not create a user" do
    assert_no_difference "User.count" do
      assert_nil @controller.send(:current_user)
    end
  end

  test "creation resets the session and reuses the guest within the request" do
    session[:marker] = "old session"
    user = nil
    assert_difference "GuestUser.count", 1 do
      user = @controller.send(:ensure_guest_user!)
      assert_same user, @controller.send(:ensure_guest_user!)
    end
    assert_equal user.id, session[:user_id]
    assert_nil session[:marker]
  end

  test "existing guest is reused without renewing creation time" do
    user = GuestUser.create!
    session[:user_id] = user.id
    assert_no_difference "User.count" do
      assert_equal user, @controller.send(:ensure_guest_user!)
    end
    assert_equal user.created_at, user.reload.created_at
  end

  test "malformed identity is cleared" do
    session[:user_id] = "invalid"
    assert_nil @controller.send(:current_user)
    assert_nil session[:user_id]
  end

  test "removed identity can be replaced" do
    user = GuestUser.create!
    session[:user_id] = user.id
    user.destroy!
    assert_nil @controller.send(:current_user)
    assert_nil session[:user_id]
    assert_not_equal user.id, @controller.send(:ensure_guest_user!).id
  end

  test "failed creation binds no identity" do
    with_failure(GuestUser, :create!, ActiveRecord::RecordInvalid.new(GuestUser.new)) do
      assert_no_difference "User.count" do
        assert_raises ActiveRecord::RecordInvalid do
          @controller.send(:ensure_guest_user!)
        end
      end
    end
    assert_nil session[:user_id]
  end

  test "database failures propagate without creating a replacement" do
    user = GuestUser.create!
    session[:user_id] = user.id
    with_failure(User, :find_by, ActiveRecord::ConnectionNotEstablished.new) do
      assert_raises ActiveRecord::ConnectionNotEstablished do
        @controller.send(:ensure_guest_user!)
      end
    end
    assert_equal user.id, session[:user_id]
  end

  private

  def with_failure(model, method_name, error)
    model.define_singleton_method(method_name) { |*| raise error }
    yield
  ensure
    model.singleton_class.remove_method(method_name)
  end
end
