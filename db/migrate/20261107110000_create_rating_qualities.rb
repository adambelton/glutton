class CreateRatingQualities < ActiveRecord::Migration[8.1]
  def change
    create_table :rating_qualities do |t|
      t.references :rating, null: false, foreign_key: { on_delete: :cascade }
      t.references :quality, null: false, foreign_key: true
      t.references :rating_quality_eval, null: false, index: false
      t.string :classification, null: false
      t.integer :score, null: false
      t.timestamps

      t.index [ :rating_quality_eval_id, :quality_id ], unique: true, name: "index_rating_qualities_on_evaluation_and_quality"
    end
  end
end
