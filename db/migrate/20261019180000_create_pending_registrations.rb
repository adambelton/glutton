class CreatePendingRegistrations < ActiveRecord::Migration[8.1]
  def change
    create_table :pending_registrations do |t|
      t.references :guest_user, null: true, index: { unique: true }, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.timestamps
    end

    add_check_constraint :pending_registrations,
      "email_address <> '' AND email_address = lower(email_address) AND email_address !~ '[[:space:]]'",
      name: "pending_registrations_require_canonical_email"
    add_check_constraint :pending_registrations, "password_digest ~ '[^[:space:]]'",
      name: "pending_registrations_require_password_digest"
  end
end
