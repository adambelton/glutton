require "test_helper"

class Identity::UserTest < ActiveSupport::TestCase
  test "guest persists an identity and fixed expiry without credentials" do
    freeze_time do
      user = Identity::UserGuest.create!
      id = user.id

      user.reload

      assert_equal id, user.id
      assert_equal Time.current, user.created_at
      assert_equal Time.current, user.updated_at
      assert_instance_of Identity::UserGuest, Identity::User.find(id)
      assert_not user.has_attribute?(:guest_expires_at)
      assert_not user.has_attribute?(:email)
      assert_nil user.email_address
      assert_nil user.password_digest
      assert_not_equal id, Identity::UserGuest.create!.id
    end
  end

  test "active guest scope evaluates the current time and excludes the expiry boundary" do
    guest = freeze_time { Identity::UserGuest.create! }
    travel_to guest.created_at + Identity::UserGuest::EXPIRY_DURATION - 1.second do
      assert_includes Identity::UserGuest.active, guest
    end
    travel_to guest.created_at + Identity::UserGuest::EXPIRY_DURATION do
      assert_not_includes Identity::UserGuest.active, guest
      assert_not guest.active?
    end
  end

  test "root construction fails while existing base rows can still be loaded" do
    assert_raises(NotImplementedError) { Identity::User.new }
    assert_raises(NotImplementedError) { Identity::User.create! }
    id = Identity::User.insert_all!([ { type: "User" } ]).rows.first.first
    assert Identity::User.find(id).active?
    assert_not Identity::User.find(id).can_register?
  end

  test "guest expires exactly at its deadline" do
    user = freeze_time { Identity::UserGuest.create! }

    travel_to (user.created_at + Identity::UserGuest::EXPIRY_DURATION) - 1.second do
      assert user.active?
    end
    travel_to (user.created_at + Identity::UserGuest::EXPIRY_DURATION) do
      assert_not user.active?
    end
    travel_to (user.created_at + Identity::UserGuest::EXPIRY_DURATION) + 1.second do
      assert_not user.active?
    end
  end

  test "reads and timestamp updates do not renew expiry" do
    user = Identity::UserGuest.create!
    expiry = user.created_at + Identity::UserGuest::EXPIRY_DURATION

    travel Identity::UserGuest::EXPIRY_DURATION / 2 do
      assert user.reload.active?
      user.touch
      assert_equal expiry, user.reload.created_at + Identity::UserGuest::EXPIRY_DURATION
    end
  end

  test "configured guest lifetime uses elapsed time across daylight saving" do
    Time.use_zone("Europe/London") do
      deadline = Time.zone.local(2026, 10, 25, 12)
      created_at = Time.at(deadline.to_i - Identity::UserGuest::EXPIRY_DURATION.to_i).in_time_zone
      user = travel_to(created_at) { Identity::UserGuest.create! }
      travel_to deadline - 1.second do
        assert Identity::User.find(user.id).active?
      end
      travel_to deadline do
        assert_not Identity::User.find(user.id).active?
      end
    end
  end

  test "registration permission follows the guest deadline and is denied by default" do
    guest = freeze_time { Identity::UserGuest.create! }
    assert guest.can_register?
    assert_not Identity::UserDeleted.create!.can_register?
    travel_to guest.created_at + Identity::UserGuest::EXPIRY_DURATION do
      assert_not guest.can_register?
    end
  end

  test "deleted users are inactive regardless of age" do
    user = Identity::UserDeleted.create!
    assert_not Identity::User.find(user.id).active?

    travel 48.hours do
      assert_not Identity::User.find(user.id).active?
    end
  end

  test "database rejects missing type without model validation" do
    assert_raises ActiveRecord::NotNullViolation do
      Identity::User.transaction(requires_new: true) do
        Identity::User.insert_all!([ { type: nil } ])
      end
    end
    assert Identity::UserGuest.create!.persisted?
  end
end
