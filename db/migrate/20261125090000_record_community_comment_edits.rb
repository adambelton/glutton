class RecordCommunityCommentEdits < ActiveRecord::Migration[8.1]
  def up
    add_column :comment_contents, :edited_at, :datetime
    execute "UPDATE comment_contents SET edited_at = updated_at WHERE updated_at <> created_at"
  end

  def down
    remove_column :comment_contents, :edited_at
  end
end
