class CreateFilmQualityCatalogue < ActiveRecord::Migration[8.1]
  def change
    create_table :quality_categories do |t|
      t.string :name, null: false
      t.integer :maximum_qualities, null: false, default: 3
      t.decimal :weight, precision: 8, scale: 3, null: false, default: 1
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :quality_categories, "lower(name)", unique: true, name: "quality_categories_name"
    add_check_constraint :quality_categories, "name = btrim(name) AND name <> ''", name: "quality_categories_name_present"
    add_check_constraint :quality_categories, "maximum_qualities >= 0", name: "quality_categories_maximum"
    add_check_constraint :quality_categories, "weight >= 0 AND weight <> 'NaN'::numeric", name: "quality_categories_weight"

    create_table :qualities do |t|
      t.references :quality_category, null: false, foreign_key: true
      t.string :name, null: false
      t.text :match_rule
      t.text :not_sufficient
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :qualities, "quality_category_id, lower(name)", unique: true, name: "qualities_category_name"
    add_check_constraint :qualities, "name = btrim(name) AND name <> ''", name: "qualities_name_present"
    add_check_constraint :qualities,
      "(match_rule IS NULL AND not_sufficient IS NULL) OR (match_rule IS NOT NULL AND match_rule ~ '[^[:space:]]' AND not_sufficient IS NOT NULL AND not_sufficient ~ '[^[:space:]]')",
      name: "qualities_complete_definitions"

    create_film_quality_evals
    create_film_qualities
  end

  def create_film_quality_evals
    create_table :film_quality_evals do |t|
      t.references :film, null: false, foreign_key: true
      t.jsonb :output, null: false
      t.jsonb :application, null: false, default: { status: "pending" }
      t.timestamps
    end
    add_index :film_quality_evals, [ :id, :film_id ], unique: true
    add_check_constraint :film_quality_evals,
      "jsonb_typeof(output) = 'object' AND output ?& ARRAY['assessed_at', 'source', 'definitions', 'categories', 'question_policy', 'minimum_support', 'model', 'support', 'evidence', 'selected_quality_ids', 'input_tokens', 'calculated_cost_usd', 'calls', 'call_count', 'selection_decisions', 'status', 'usage_complete'] AND COALESCE(output->>'status' IN ('completed', 'failed'), false)",
      name: "film_quality_evals_completed_output"
    add_check_constraint :film_quality_evals,
      "jsonb_typeof(application) = 'object' AND COALESCE(application->>'status' IN ('pending', 'applied', 'failed'), false)",
      name: "film_quality_evals_application"
  end

  def create_film_qualities
    create_table :film_qualities do |t|
      t.references :film, null: false, foreign_key: true
      t.references :quality, null: false, foreign_key: true
      t.references :film_quality_eval
      t.timestamps
    end
    add_index :film_qualities, [ :film_id, :quality_id ], unique: true
    add_foreign_key :film_qualities, :film_quality_evals,
      column: [ :film_quality_eval_id, :film_id ], primary_key: [ :id, :film_id ]
  end
end
