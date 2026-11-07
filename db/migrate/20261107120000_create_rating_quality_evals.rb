class CreateRatingQualityEvals < ActiveRecord::Migration[8.1]
  def change
    create_table :rating_quality_evals do |t|
      t.references :rating, null: false, foreign_key: { on_delete: :cascade }
      t.jsonb :output, null: false
      t.timestamps
    end

    add_check_constraint :rating_quality_evals,
      "jsonb_typeof(output) = 'object' AND output ?& ARRAY['expressions', 'qualities', 'calls', 'decisions']",
      name: "rating_quality_evals_completed_output"
  end
end
