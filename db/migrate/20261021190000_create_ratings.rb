class CreateRatings < ActiveRecord::Migration[8.1]
  def change
    create_table :ratings do |t|
      t.references :rating_film, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.string :value, null: false
      t.timestamps
      t.check_constraint "value IN ('brilliant', 'enjoyed', 'not_for_me', 'garbage')", name: "ratings_value_allowed"
    end
  end
end
