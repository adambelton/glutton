class AddCommunityCommentReplies < ActiveRecord::Migration[8.1]
  def change
    add_reference :comments, :parent
    add_reference :comments, :root
    change_column_null :comments, :film_endorsement_id, true

    add_index :comments, [ :post_id, :id ], unique: true
    add_foreign_key :comments, :comments, column: [ :post_id, :parent_id ], primary_key: [ :post_id, :id ], on_delete: :cascade
    add_foreign_key :comments, :comments, column: [ :post_id, :root_id ], primary_key: [ :post_id, :id ], on_delete: :cascade
    add_check_constraint :comments, <<~SQL.squish, name: "comments_root_or_reply"
      (film_endorsement_id IS NOT NULL AND parent_id IS NULL AND root_id IS NULL)
      OR (film_endorsement_id IS NULL AND parent_id IS NOT NULL AND root_id IS NOT NULL AND parent_id <> id AND root_id <> id)
    SQL
  end
end
