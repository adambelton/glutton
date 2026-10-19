class UseUserTypes < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :type, :string, null: false, default: "GuestUser"
    change_column_default :users, :type, from: "GuestUser", to: nil
    remove_column :users, :guest_expires_at
  end

  def down
    add_column :users, :guest_expires_at, :datetime
    execute "UPDATE users SET guest_expires_at = created_at + INTERVAL '24 hours'"
    change_column_null :users, :guest_expires_at, false
    remove_column :users, :type
  end
end
