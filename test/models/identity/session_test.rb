require "test_helper"

class Identity::SessionTest < ActiveSupport::TestCase
  def registered_user
    Identity::UserRegistered.create!(email_address: "session@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
  end

  test "resuming a session returns only its active owning identity" do
    user = Identity::UserGuest.create!
    authentication = Identity::Session.create!(user:)
    other = Identity::UserGuest.create!
    assert_equal user, Identity::Session.resume(id: authentication.id, user_id: user.id)
    assert_nil Identity::Session.resume(id: authentication.id, user_id: other.id)
    assert_nil Identity::Session.resume(id: nil, user_id: user.id)
    Identity::Session.revoke(id: authentication.id)
    assert_nil Identity::Session.resume(id: authentication.id, user_id: user.id)
  end

  test "expired guests cannot resume and deleted accounts reject even a missing session" do
    freeze_time
    user = Identity::UserGuest.create!
    authentication = Identity::Session.create!(user:)
    travel_to user.created_at + Identity::UserGuest::EXPIRY_DURATION - 1.second do
      assert_nil user.inactive_error
      assert_equal user, Identity::Session.resume(id: authentication.id, user_id: user.id)
    end
    [ 0.seconds, 1.second ].each do |offset|
      travel_to user.created_at + Identity::UserGuest::EXPIRY_DURATION + offset do
        assert_raises(Identity::Errors::GuestExpired) { Identity::Session.resume(id: authentication.id, user_id: user.id) }
        assert_raises(Identity::Errors::GuestExpired) { Identity::Session.resume(id: nil, user_id: user.id) }
      end
    end
    deleted = Identity::UserDeleted.create!
    assert_raises(Identity::Errors::AccountDeleted) { Identity::Session.resume(id: nil, user_id: deleted.id) }
  end

  test "guest issuance preserves account identity and deadline" do
    guest = Identity::UserGuest.create!
    attributes = guest.slice(:id, :created_at, :email_address, :password_digest)
    session = Identity::Session.create!(user: guest)
    assert session.active?
    assert_equal guest.id, session.user_id
    assert_equal attributes, guest.reload.slice(:id, :created_at, :email_address, :password_digest)
  end

  test "guest activity follows the account deadline rather than session age" do
    guest = freeze_time { Identity::UserGuest.create! }
    travel_to guest.created_at + Identity::UserGuest::EXPIRY_DURATION / 2 do
      session = Identity::Session.create!(user: guest)
      assert session.active?
    end
    session = Identity::Session.find_by!(user: guest)
    travel_to guest.created_at + Identity::UserGuest::EXPIRY_DURATION - 1.second do
      assert session.active?
    end
    travel_to guest.created_at + Identity::UserGuest::EXPIRY_DURATION do
      assert_not session.active?
      assert_not Identity::Session.new(user: guest).valid?
    end
    travel_to guest.created_at + Identity::UserGuest::EXPIRY_DURATION + 1.hour do
      assert_not session.active?
    end
  end

  test "registered sessions have no age deadline" do
    user = registered_user
    session = Identity::Session.create!(user: user)
    attributes = session.slice(:id, :user_id, :created_at)
    travel 365.days do
      assert session.active?
      assert user.active?
      assert_equal attributes, session.reload.slice(:id, :user_id, :created_at)
    end
  end

  test "deleted owner is detected despite cached associations" do
    user = registered_user
    session = Identity::Session.create!(user: user)
    assert session.user.can_reset_password?
    user.update_columns(type: "UserDeleted", email_address: nil, password_digest: nil, email_confirmed_at: nil)
    assert_not session.active?
    assert_not Identity::Session.find(session.id).user.active?
    assert_not Identity::Session.new(user: user).valid?
  end

  test "only persisted active owners can hold sessions" do
    [ nil, Identity::UserGuest.new, Identity::UserDeleted.create! ].each do |owner|
      assert_not Identity::Session.new(user: owner).valid?
    end
    assert_not Identity::Session.new.active?
  end

  test "guest sessions can be revoked independently and repeatedly" do
    user = Identity::UserGuest.create!
    first = Identity::Session.create!(user: user)
    second = Identity::Session.create!(user: user)
    assert Identity::Session.revoke(id: first.id)
    assert Identity::Session.revoke(id: first.id)
    assert_nil Identity::Session.find_by(id: first.id)
    assert_not first.active?
    assert second.active?
    assert_equal user, second.user
  end

  test "inactive owner errors retain a symbol and translated message" do
    session = Identity::Session.new(user: Identity::UserDeleted.create!)
    assert_not session.valid?
    assert_includes session.errors.details[:user], { error: :inactive }
    assert_includes session.errors[:user], "must be active"
  end

  test "database requires a valid nonnull owner independently of validation" do
    assert_raises ActiveRecord::NotNullViolation do
      Identity::Session.transaction(requires_new: true) { Identity::Session.new.save!(validate: false) }
    end
    assert_raises ActiveRecord::InvalidForeignKey do
      Identity::Session.transaction(requires_new: true) { Identity::Session.new(user_id: -1).save!(validate: false) }
    end
    assert Identity::Session.create!(user: Identity::UserGuest.create!).persisted?
  end
end
