class CreateCommunityModeratorRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :community_moderator_roles do |t|
      t.references :member, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :granted_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :revoked_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :granted_at, null: false
      t.datetime :revoked_at

      t.index :member_id, unique: true, where: "revoked_at IS NULL", name: "one_active_community_moderator_role_per_member"
      t.check_constraint "revoked_at IS NOT NULL OR revoked_by_id IS NULL", name: "community_moderator_revocation_requires_time"
    end
  end
end
