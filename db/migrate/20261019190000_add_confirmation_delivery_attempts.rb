class AddConfirmationDeliveryAttempts < ActiveRecord::Migration[8.1]
  def change
    add_column :pending_registrations, :confirmation_delivery_attempts, :integer, null: false, default: 0
    add_column :pending_registrations, :confirmation_delivery_attempted_at, :datetime
    add_check_constraint :pending_registrations, "confirmation_delivery_attempts BETWEEN 0 AND 5",
      name: "pending_registration_delivery_limit"
  end
end
