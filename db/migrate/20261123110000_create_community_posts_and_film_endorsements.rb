class CreateCommunityPostsAndFilmEndorsements < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.string :type, null: false
      t.references :author, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :title
      t.text :prompt
      t.timestamps
      t.index [ :type, :created_at, :id ]
    end

    create_table :film_endorsements do |t|
      t.references :post, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :film, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
      t.index [ :post_id, :film_id, :user_id ], unique: true
    end
  end
end
