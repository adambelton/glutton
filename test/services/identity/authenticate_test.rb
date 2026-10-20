require "test_helper"

class Identity::AuthenticateTest < ActiveSupport::TestCase
  setup do
    @user = UserRegistered.create!(email_address: "viewer@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
  end

  test "normalized credentials issue independent sessions without changing the account" do
    attributes = @user.slice(:id, :email_address, :password_digest, :email_confirmed_at, :created_at)
    first = second = nil
    assert_no_difference "User.count" do
      assert_difference "Session.count", 2 do
        first = Identity::Authenticate.call(email_address: " VIEWER@Example.TEST ", password: "a long password phrase")
        second = Identity::Authenticate.call(email_address: @user.email_address, password: "a long password phrase")
      end
    end
    assert first.persisted?
    assert_equal @user.id, first.user_id
    assert_not_equal first.id, second.id
    assert_equal attributes, @user.reload.slice(:id, :email_address, :password_digest, :email_confirmed_at, :created_at)
    Session.revoke(id: first.id)
    assert_not first.active?
    assert second.active?
  end

  test "invalid inputs return no session or user" do
    inputs = [ [ @user.email_address, "wrong password" ], [ "unknown@example.test", "a long password phrase" ],
      [ "invalid", "a long password phrase" ], [ nil, "password" ], [ [], "password" ],
      [ "", "password" ], [ " \t", "password" ], [ @user.email_address, nil ],
      [ @user.email_address, [] ], [ @user.email_address, "" ], [ @user.email_address, "  " ] ]
    assert_no_difference [ "Session.count", "User.count" ] do
      inputs.each do |email, password|
        assert_nil Identity::Authenticate.call(email_address: email, password: password)
      end
    end
  end

  test "guest and deleted identities cannot authenticate with registered credentials" do
    guest = UserGuest.create!
    @user.update_columns(type: "UserDeleted", email_address: nil, password_digest: nil, email_confirmed_at: nil)
    assert_no_difference [ "Session.count", "User.count" ] do
      assert_nil Identity::Authenticate.call(email_address: "viewer@example.test", password: "a long password phrase")
      assert_nil Identity::Authenticate.call(email_address: guest.email_address, password: "a long password phrase")
    end
  end

  test "issuance errors propagate without partial sessions or account changes" do
    attributes = @user.slice(:id, :email_address, :password_digest, :email_confirmed_at, :created_at)
    Session.define_singleton_method(:create!) { |**| raise ActiveRecord::ConnectionNotEstablished }
    assert_no_difference [ "Session.count", "User.count" ] do
      assert_raises ActiveRecord::ConnectionNotEstablished do
        Identity::Authenticate.call(email_address: @user.email_address, password: "a long password phrase")
      end
    end
    assert_equal attributes, @user.reload.slice(:id, :email_address, :password_digest, :email_confirmed_at, :created_at)
  ensure
    Session.singleton_class.remove_method(:create!)
  end
end
