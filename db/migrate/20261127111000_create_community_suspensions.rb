class CreateCommunitySuspensions < ActiveRecord::Migration[8.1]
  def change
    create_table :community_suspensions do |t|
      t.references :member, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :suspended_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :lifted_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :suspended_at, null: false
      t.datetime :lifted_at

      t.index :member_id, unique: true, where: "lifted_at IS NULL", name: "one_active_community_suspension_per_member"
      t.check_constraint "lifted_at IS NOT NULL OR lifted_by_id IS NULL", name: "community_suspension_lift_requires_time"
    end
  end
end
