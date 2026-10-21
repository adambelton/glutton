class CreateRatingFilms < ActiveRecord::Migration[8.1]
  def change
    create_table :rating_films do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :film, null: false, foreign_key: true
      t.boolean :dismissed, null: false, default: false
      t.timestamps
    end
    add_index :rating_films, [ :user_id, :film_id ], unique: true
  end
end
