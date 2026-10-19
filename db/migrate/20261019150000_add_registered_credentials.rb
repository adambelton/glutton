class AddRegisteredCredentials < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email_address, :string
    add_column :users, :password_digest, :string
    add_column :users, :email_confirmed_at, :datetime
    add_index :users, :email_address, unique: true

    add_check_constraint :users, <<~SQL.squish, name: "registered_users_require_credentials"
      type <> 'RegisteredUser' OR (
        email_address IS NOT NULL AND email_address <> ''
        AND email_address = lower(email_address)
        AND email_address !~ '[[:space:]]'
        AND password_digest IS NOT NULL AND password_digest ~ '[^[:space:]]'
        AND email_confirmed_at IS NOT NULL
      )
    SQL
    add_check_constraint :users, <<~SQL.squish, name: "other_users_have_no_credentials"
      type = 'RegisteredUser' OR (
        email_address IS NULL AND password_digest IS NULL AND email_confirmed_at IS NULL
      )
    SQL
  end
end
