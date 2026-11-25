class ProtectCommunityCurations < ActiveRecord::Migration[8.1]
  def up
    add_column :posts, :protected_at, :datetime
    add_column :posts, :additional_description, :text
    add_reference :posts, :deletable_author, foreign_key: { to_table: :users, on_delete: :cascade }
    execute "UPDATE posts SET deletable_author_id = author_id WHERE type = 'Community::PostCommunityCuration'"
    remove_foreign_key :posts, :users, column: :author_id
    add_foreign_key :posts, :users, column: :author_id, on_delete: :nullify
    add_check_constraint :posts, <<~SQL.squish, name: :curations_require_deletion_owner_until_protected
      type <> 'Community::PostCommunityCuration' OR (
        (protected_at IS NULL) = (deletable_author_id IS NOT NULL)
        AND (author_id IS NULL OR deletable_author_id IS NULL OR author_id = deletable_author_id)
      )
    SQL
  end

  def down
    if select_value("SELECT EXISTS (SELECT 1 FROM posts WHERE protected_at IS NOT NULL)")
      raise ActiveRecord::IrreversibleMigration, "Protected curations may have surviving contributions without an author"
    end

    remove_check_constraint :posts, name: :curations_require_deletion_owner_until_protected
    remove_foreign_key :posts, :users, column: :author_id
    add_foreign_key :posts, :users, column: :author_id, on_delete: :cascade
    remove_reference :posts, :deletable_author, foreign_key: { to_table: :users }
    remove_column :posts, :additional_description
    remove_column :posts, :protected_at
  end
end
