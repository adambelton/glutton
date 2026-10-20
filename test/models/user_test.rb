require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "guest persists an identity and fixed expiry without credentials" do
    freeze_time do
      user = UserGuest.create!
      id = user.id

      user.reload

      assert_equal id, user.id
      assert_equal Time.current, user.created_at
      assert_equal Time.current, user.updated_at
      assert_instance_of UserGuest, User.find(id)
      assert_not user.has_attribute?(:guest_expires_at)
      assert_not user.has_attribute?(:email)
      assert_nil user.email_address
      assert_nil user.password_digest
      assert_not_equal id, UserGuest.create!.id
    end
  end

  test "active guest scope evaluates the current time and excludes the expiry boundary" do
    guest = freeze_time { UserGuest.create! }
    travel_to guest.created_at + 24.hours - 1.second do
      assert_includes UserGuest.active, guest
    end
    travel_to guest.created_at + 24.hours do
      assert_not_includes UserGuest.active, guest
      assert_not guest.active?
    end
  end

  test "root construction fails while existing base rows can still be loaded" do
    assert_raises(NotImplementedError) { User.new }
    assert_raises(NotImplementedError) { User.create! }
    id = User.insert_all!([ { type: "User" } ]).rows.first.first
    assert User.find(id).active?
    assert_not User.find(id).can_register?
  end

  test "guest expires exactly at its deadline" do
    user = freeze_time { UserGuest.create! }

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
    user = UserGuest.create!
    expiry = user.created_at + 24.hours

    travel 12.hours do
      assert user.reload.active?
      user.touch
      assert_equal expiry, user.reload.created_at + 24.hours
    end
  end

  test "guest lifetime is 24 elapsed hours across daylight saving" do
    Time.use_zone("Europe/London") do
      user = travel_to(Time.zone.local(2026, 10, 24, 12)) { UserGuest.create! }
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

  test "registration permission follows the guest deadline and is denied by default" do
    guest = freeze_time { UserGuest.create! }
    assert guest.can_register?
    assert_not UserDeleted.create!.can_register?
    travel_to guest.created_at + 24.hours do
      assert_not guest.can_register?
    end
  end

  test "deleted users are inactive regardless of age" do
    user = UserDeleted.create!
    assert_not User.find(user.id).active?

    travel 48.hours do
      assert_not User.find(user.id).active?
    end
  end

  test "database rejects missing type without model validation" do
    assert_raises ActiveRecord::NotNullViolation do
      User.transaction(requires_new: true) do
        User.insert_all!([ { type: nil } ])
      end
    end
    assert UserGuest.create!.persisted?
  end
end
