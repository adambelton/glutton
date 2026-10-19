require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "guest persists an identity and fixed expiry without credentials" do
    freeze_time do
      user = GuestUser.create!
      id = user.id

      user.reload

      assert_equal id, user.id
      assert_equal Time.current, user.created_at
      assert_equal Time.current, user.updated_at
      assert_instance_of GuestUser, User.find(id)
      assert_not user.has_attribute?(:guest_expires_at)
      assert_not user.has_attribute?(:email)
      assert_not user.has_attribute?(:email_address)
      assert_not user.has_attribute?(:password_digest)
      assert_not_equal id, GuestUser.create!.id
    end
  end

  test "base users are active" do
    assert User.new.active?
  end

  test "guest expires exactly at its deadline" do
    user = freeze_time { GuestUser.create! }

    travel_to (user.created_at + 24.hours) - 1.second do
      assert user.active?
    end
    travel_to (user.created_at + 24.hours) do
      assert_not user.active?
    end
    travel_to (user.created_at + 24.hours) + 1.second do
      assert_not user.active?
    end
  end

  test "reads and timestamp updates do not renew expiry" do
    user = GuestUser.create!
    expiry = user.created_at + 24.hours

    travel 12.hours do
      assert user.reload.active?
      user.touch
      assert_equal expiry, user.reload.created_at + 24.hours
    end
  end

  test "guest lifetime is 24 elapsed hours across daylight saving" do
    Time.use_zone("Europe/London") do
      user = travel_to(Time.zone.local(2026, 10, 24, 12)) { GuestUser.create! }
      travel_time = user.created_at + 24.hours
      assert_equal 11, travel_time.in_time_zone.hour
      travel_to travel_time - 1.second do
        assert User.find(user.id).active?
      end
      travel_to travel_time do
        assert_not User.find(user.id).active?
      end
    end
  end

  test "deleted users are inactive regardless of age" do
    user = DeletedUser.create!
    assert_not User.find(user.id).active?

    travel 48.hours do
      assert_not User.find(user.id).active?
    end
  end

  test "type is required by the model" do
    user = User.new

    assert_not user.valid?
    assert_includes user.errors[:type], "can't be blank"
  end

  test "database rejects missing type without model validation" do
    assert_raises ActiveRecord::NotNullViolation do
      User.transaction(requires_new: true) do
        User.new.save!(validate: false)
      end
    end
    assert GuestUser.create!.persisted?
  end
end
