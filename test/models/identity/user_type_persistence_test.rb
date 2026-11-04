require "test_helper"

class Identity::UserTypePersistenceTest < ActiveSupport::TestCase
  test "fresh schema protects registered credentials and preserves session identity on rejected changes" do
    registered = Identity::UserRegistered.create!(email_address: "migration@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    guest = Identity::UserGuest.create!
    session = Identity::Session.create!(user: registered)
    assert_raises(ActiveRecord::StatementInvalid) do
      Identity::User.transaction(requires_new: true) { registered.update_columns(type: "UserGuest") }
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Identity::User.transaction(requires_new: true) { guest.update_columns(type: "UserRegistered") }
    end
    assert_equal registered.id, session.reload.user_id
    assert registered.reload.authenticate("a long password phrase")
    assert_equal "UserGuest", guest.reload.type
  end

  test "namespaced lifecycle classes retain existing STI labels and users table" do
    assert_equal "UserGuest", Identity::UserGuest.create!.reload.type
    assert_equal "UserDeleted", Identity::UserDeleted.create!.reload.type
    assert_equal "UserRegistered", Identity::UserRegistered.sti_name
    assert_equal "Identity::UserRegistered", Identity::User.sti_class_for("UserRegistered").name
    assert_equal "users", Identity::UserRegistered.table_name
  end
end
