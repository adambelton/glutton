class AllowCurationEndorsementWithdrawals < ActiveRecord::Migration[8.1]
  def change
    add_column :film_endorsements, :withdrawn_at, :datetime
    remove_index :film_endorsements, [ :post_id, :film_id, :user_id ], unique: true
    add_index :film_endorsements, [ :post_id, :film_id, :user_id ], unique: true, where: "withdrawn_at IS NULL"
  end
end
