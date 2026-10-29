require "test_helper"

class UserTypePersistenceTest < ActiveSupport::TestCase
  test "fresh schema protects registered credentials and preserves session identity on rejected changes" do
    registered = UserRegistered.create!(email_address: "migration@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    guest = UserGuest.create!
    session = Session.create!(user: registered)
    assert_raises(ActiveRecord::StatementInvalid) do
      User.transaction(requires_new: true) { registered.update_columns(type: "UserGuest") }
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      User.transaction(requires_new: true) { guest.update_columns(type: "UserRegistered") }
    end
    assert_equal registered.id, session.reload.user_id
    assert registered.reload.authenticate("a long password phrase")
    assert_equal "UserGuest", guest.reload.type
  end

  test "lifecycle classes use their names as STI values and default Rails paths" do
    assert_equal "UserGuest", UserGuest.create!.reload.type
    assert_equal "UserDeleted", UserDeleted.create!.reload.type
    assert_equal "UserRegistered", UserRegistered.sti_name
    assert_equal "UserRegistered", User.sti_class_for("UserRegistered").name
    assert_equal "users", UserRegistered.table_name
  end
end
