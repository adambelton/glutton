require "test_helper"
require Rails.root.join("db/migrate/20261020120000_rename_user_types")

class RenameUserTypesTest < ActiveSupport::TestCase
  test "migration preserves identities credentials and sessions in both directions" do
    registered = UserRegistered.create!(email_address: "migration@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    users = [ registered, UserGuest.create!, UserDeleted.create!, User.find(User.insert_all!([ { type: "User" } ]).rows.first.first) ]
    session = Session.create!(user: registered)
    connection = User.connection
    snapshot = connection.select_all("SELECT * FROM users ORDER BY id").to_a
    sessions = connection.select_all("SELECT * FROM sessions ORDER BY id").to_a
    migration = RenameUserTypes.new

    ActiveRecord::Migration.suppress_messages { migration.down }
    legacy = connection.select_all("SELECT * FROM users ORDER BY id").to_a
    assert_equal snapshot.map { |row| row.merge("type" => { "UserRegistered" => "RegisteredUser", "UserGuest" => "GuestUser", "UserDeleted" => "DeletedUser" }.fetch(row["type"], row["type"])) }, legacy
    assert_raises(ActiveRecord::StatementInvalid) do
      User.transaction(requires_new: true) { connection.execute("UPDATE users SET type = 'GuestUser' WHERE id = #{registered.id}") }
    end

    ActiveRecord::Migration.suppress_messages { migration.up }
    assert_equal snapshot, connection.select_all("SELECT * FROM users ORDER BY id").to_a
    assert_equal sessions, connection.select_all("SELECT * FROM sessions ORDER BY id").to_a
    assert_equal [ UserRegistered, UserGuest, UserDeleted, User ], users.map { |user| User.find(user.id).class }
    assert_equal registered.id, Session.find(session.id).user.id
    assert User.find(registered.id).authenticate("a long password phrase")
    assert_raises(ActiveRecord::StatementInvalid) do
      User.transaction(requires_new: true) { connection.execute("UPDATE users SET type = 'UserGuest' WHERE id = #{registered.id}") }
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      User.transaction(requires_new: true) { connection.execute("UPDATE users SET type = 'UserRegistered' WHERE id = #{users[1].id}") }
    end
  end

  test "lifecycle classes use their names as STI values and default Rails paths" do
    assert_equal "UserGuest", UserGuest.create!.reload.type
    assert_equal "UserDeleted", UserDeleted.create!.reload.type
    assert_equal "UserRegistered", UserRegistered.sti_name
    assert_equal "UserRegistered", User.sti_class_for("UserRegistered").name
    assert_equal "users", UserRegistered.table_name
  end
end
