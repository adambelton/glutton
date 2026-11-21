class ConstrainUserTypes < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :users, "type IN ('UserGuest', 'UserRegistered')", name: "users_supported_type"
  end
end
