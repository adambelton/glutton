class AllowFilmDebriefComments < ActiveRecord::Migration[8.1]
  def change
    add_column :comments, :debrief_film_id, :bigint
    add_index :posts, [ :id, :film_id ], unique: true
    add_foreign_key :comments, :posts, column: [ :post_id, :debrief_film_id ],
      primary_key: [ :id, :film_id ], on_delete: :cascade

    remove_check_constraint :comments, <<~SQL.squish, name: :comments_root_or_reply
      (film_endorsement_id IS NOT NULL AND parent_id IS NULL AND root_id IS NULL)
      OR (film_endorsement_id IS NULL AND parent_id IS NOT NULL AND root_id IS NOT NULL AND parent_id <> id AND root_id <> id)
    SQL
    add_check_constraint :comments, <<~SQL.squish, name: :comments_root_or_reply
      (num_nonnulls(film_endorsement_id, debrief_film_id) = 1 AND parent_id IS NULL AND root_id IS NULL)
      OR (film_endorsement_id IS NULL AND debrief_film_id IS NULL AND parent_id IS NOT NULL AND root_id IS NOT NULL
        AND parent_id <> id AND root_id <> id)
    SQL
  end
end
