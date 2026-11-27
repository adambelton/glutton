class CreateCommunityMemberBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :community_member_blocks do |t|
      t.references :blocker, null: false, index: false,
        foreign_key: { to_table: :community_users, primary_key: :user_id, on_delete: :cascade }
      t.references :blocked, null: false,
        foreign_key: { to_table: :community_users, primary_key: :user_id, on_delete: :cascade }
      t.timestamps

      t.index [ :blocker_id, :blocked_id ], unique: true
      t.check_constraint "blocker_id <> blocked_id", name: "community_member_blocks_distinct_members"
    end
  end
end
