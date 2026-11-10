class CreateRatings < ActiveRecord::Migration[8.1]
  def change
    create_table :ratings do |t|
      t.references :rating_film, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string :value, null: false
      t.text :notes
      t.check_constraint "char_length(notes) BETWEEN 1 AND 8000", name: "ratings_notes_length"
      t.timestamps
      t.check_constraint "value IN ('brilliant', 'pretty_good', 'not_for_me', 'garbage')", name: "ratings_value_allowed"
    end
    add_index :ratings, [ :rating_film_id, :id ]
  end
end
