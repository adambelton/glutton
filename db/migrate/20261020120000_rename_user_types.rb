class RenameUserTypes < ActiveRecord::Migration[8.1]
  def up
    replace_types("GuestUser" => "UserGuest", "RegisteredUser" => "UserRegistered", "DeletedUser" => "UserDeleted")
    add_credential_constraints("UserRegistered")
  end

  def down
    replace_types("UserGuest" => "GuestUser", "UserRegistered" => "RegisteredUser", "UserDeleted" => "DeletedUser")
    add_credential_constraints("RegisteredUser")
  end

  private
    def replace_types(mapping)
      remove_check_constraint :users, name: "registered_users_require_credentials"
      remove_check_constraint :users, name: "other_users_have_no_credentials"
      mapping.each do |old_type, new_type|
        execute "UPDATE users SET type = #{connection.quote(new_type)} WHERE type = #{connection.quote(old_type)}"
      end
    end

    def add_credential_constraints(registered_type)
      registered = connection.quote(registered_type)
      add_check_constraint :users, <<~SQL.squish, name: "registered_users_require_credentials"
        type <> #{registered} OR (
          email_address IS NOT NULL AND email_address <> ''
          AND email_address = lower(email_address)
          AND email_address !~ '[[:space:]]'
          AND password_digest IS NOT NULL AND password_digest ~ '[^[:space:]]'
          AND email_confirmed_at IS NOT NULL
        )
      SQL
      add_check_constraint :users, <<~SQL.squish, name: "other_users_have_no_credentials"
        type = #{registered} OR (
          email_address IS NULL AND password_digest IS NULL AND email_confirmed_at IS NULL
        )
      SQL
    end
end
