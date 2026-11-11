class CreateLibraryFilms < ActiveRecord::Migration[8.1]
  def change
    create_table :library_films do |t|
      t.boolean :watched, null: false, default: false
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :film, null: false, foreign_key: true
      t.timestamps
    end
    add_index :library_films, [ :user_id, :film_id ], unique: true
  end
end
