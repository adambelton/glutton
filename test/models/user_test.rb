require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "guest persists an identity and fixed expiry without credentials" do
    freeze_time do
      user = User.create_guest!
      id = user.id

      user.reload

      assert_equal id, user.id
      assert_equal Time.current, user.created_at
      assert_equal Time.current, user.updated_at
      assert_equal user.created_at + 24.hours, user.guest_expires_at
      assert_not user.has_attribute?(:email)
      assert_not user.has_attribute?(:email_address)
      assert_not user.has_attribute?(:password_digest)
      assert_not_equal id, User.create_guest!.id
    end
  end

  test "guest expires exactly at its deadline" do
    user = freeze_time { User.create_guest! }

    travel_to user.guest_expires_at - 1.second do
      assert_not user.guest_expired?
    end
    travel_to user.guest_expires_at do
      assert user.guest_expired?
    end
    travel_to user.guest_expires_at + 1.second do
      assert user.guest_expired?
    end
  end

  test "reads and timestamp updates do not renew expiry" do
    user = User.create_guest!
    expiry = user.guest_expires_at

    travel 12.hours do
      assert_not user.reload.guest_expired?
      user.touch
      assert_equal expiry, user.reload.guest_expires_at
    end
  end

  test "expiry is required by the model" do
    user = User.new

    assert_not user.valid?
    assert_includes user.errors[:guest_expires_at], "can't be blank"
  end

  test "database rejects missing expiry without model validation" do
    assert_raises ActiveRecord::NotNullViolation do
      User.transaction(requires_new: true) do
        User.new.save!(validate: false)
      end
    end
    assert User.create_guest!.persisted?
  end
end
