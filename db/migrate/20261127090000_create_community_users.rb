class CreateCommunityUsers < ActiveRecord::Migration[8.1]
  def up
    create_table :community_users, id: false do |t|
      t.bigint :user_id, primary_key: true
      t.string :community_username
      t.string :community_avatar_preset
      t.index 'lower(community_username COLLATE "C")', unique: true, name: "community_users_username_unique"
    end
    add_foreign_key :community_users, :users, on_delete: :cascade

    replace_community_user_reference(:posts, :author_id, :community_user_id, on_delete: :nullify)
    replace_community_user_reference(:posts, :deletable_author_id, :deletable_community_user_id, on_delete: :cascade)
    replace_community_user_reference(:comment_contents, :author_id, :community_user_id, on_delete: :cascade)

    remove_columns :users, :community_username, :community_avatar_preset
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Restore the pre-cutover database to recover legacy profile columns"
  end

  private

  def replace_community_user_reference(table, legacy_column, column, on_delete:)
    remove_foreign_key(table, :users, column: legacy_column)
    rename_column(table, legacy_column, column)
    # Existing staging rows are checked after importing their Community users.
    existing_authors = select_value("SELECT EXISTS (SELECT 1 FROM #{table} WHERE #{column} IS NOT NULL)")
    add_foreign_key(table, :community_users, column:, primary_key: :user_id, on_delete:, validate: !existing_authors)
  end
end
