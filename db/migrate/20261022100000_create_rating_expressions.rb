class CreateRatingExpressions < ActiveRecord::Migration[8.1]
  def change
    create_table :rating_expressions do |t|
      t.references :rating, null: false, foreign_key: { on_delete: :cascade }
      t.text :text, null: false
      t.timestamps
    end

    add_check_constraint :rating_expressions, "char_length(text) <= 2000", name: "rating_expressions_text_length"
  end
end
