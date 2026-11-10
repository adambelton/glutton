class CreateRatingQualityEvals < ActiveRecord::Migration[8.1]
  def change
    create_table :rating_quality_evals do |t|
      t.references :rating, null: false, foreign_key: { on_delete: :cascade }
      t.jsonb :input, null: false, default: []
      t.jsonb :output, null: false
      t.timestamps
    end

    add_check_constraint :rating_quality_evals, "jsonb_typeof(input) = 'array'", name: "rating_quality_evals_input_calls"
    add_check_constraint :rating_quality_evals,
      "jsonb_typeof(output) = 'object' AND output ?& ARRAY['notes', 'qualities', 'calls', 'decisions']",
      name: "rating_quality_evals_completed_output"

    add_index :rating_quality_evals, [ :id, :rating_id ], unique: true
    add_foreign_key :rating_qualities, :rating_quality_evals,
      column: [ :rating_quality_eval_id, :rating_id ], primary_key: [ :id, :rating_id ], on_delete: :cascade
  end
end
