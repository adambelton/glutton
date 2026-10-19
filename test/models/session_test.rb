require "test_helper"

class SessionTest < ActiveSupport::TestCase
  def registered_user
    RegisteredUser.create!(email_address: "session@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
  end

  test "guest issuance preserves account identity and deadline" do
    guest = GuestUser.create!
    attributes = guest.attributes
    session = Session.create!(user: guest)
    assert session.active?
    assert_equal guest.id, session.user_id
    assert_equal attributes, guest.reload.attributes
  end

  test "guest activity follows the account deadline rather than session age" do
    guest = freeze_time { GuestUser.create! }
    travel_to guest.created_at + 23.hours do
      session = Session.create!(user: guest)
      assert session.active?
    end
    session = Session.find_by!(user: guest)
    travel_to guest.created_at + 24.hours - 1.second do
      assert session.active?
    end
    travel_to guest.created_at + 24.hours do
      assert_not session.active?
      assert_not Session.new(user: guest).valid?
    end
    travel_to guest.created_at + 25.hours do
      assert_not session.active?
    end
  end

  test "registered sessions have no age deadline" do
    user = registered_user
    session = Session.create!(user: user)
    attributes = session.attributes
    travel 365.days do
      assert session.active?
      assert user.active?
      assert_equal attributes, session.reload.attributes
    end
  end

  test "deleted owner is detected despite cached associations" do
    user = registered_user
    session = Session.create!(user: user)
    assert_instance_of RegisteredUser, session.user
    user.update_columns(type: "DeletedUser", email_address: nil, password_digest: nil, email_confirmed_at: nil)
    assert_not session.active?
    assert_instance_of DeletedUser, Session.find(session.id).user
    assert_not Session.new(user: user).valid?
  end

  test "only persisted active owners can hold sessions" do
    [ nil, GuestUser.new, DeletedUser.create! ].each do |owner|
      assert_not Session.new(user: owner).valid?
    end
    assert_not Session.new.active?
  end

  test "guest sessions can be revoked independently and repeatedly" do
    user = GuestUser.create!
    first = Session.create!(user: user)
    second = Session.create!(user: user)
    assert Session.revoke(id: first.id)
    assert Session.revoke(id: first.id)
    assert_nil Session.find_by(id: first.id)
    assert_not first.active?
    assert second.active?
    assert_equal user, second.user
  end

  test "inactive owner errors retain a symbol and translated message" do
    session = Session.new(user: DeletedUser.create!)
    assert_not session.valid?
    assert_includes session.errors.details[:user], { error: :inactive }
    assert_includes session.errors[:user], "must be active"
  end

  test "database requires a valid nonnull owner independently of validation" do
    assert_raises ActiveRecord::NotNullViolation do
      Session.transaction(requires_new: true) { Session.new.save!(validate: false) }
    end
    assert_raises ActiveRecord::InvalidForeignKey do
      Session.transaction(requires_new: true) { Session.new(user_id: -1).save!(validate: false) }
    end
    assert Session.create!(user: GuestUser.create!).persisted?
  end
end
