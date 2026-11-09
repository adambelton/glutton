class CreateExpressionProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :expression_profiles do |t|
      t.references :user, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.timestamps
    end

    create_table :expression_profile_revision_evals do |t|
      t.references :expression_profile, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.jsonb :input, null: false, default: []
      t.jsonb :output, null: false
      t.timestamps
    end

    add_index :expression_profile_revision_evals, [ :expression_profile_id, :id ], unique: true
    add_check_constraint :expression_profile_revision_evals, "jsonb_typeof(input) = 'array'", name: "expression_profile_revision_evals_input_calls"
    add_check_constraint :expression_profile_revision_evals, <<~SQL.squish, name: "expression_profile_revision_evals_completed_output"
      jsonb_typeof(output) = 'object' AND output ?& ARRAY['evidence', 'profile', 'synthesis', 'trace_id']
      AND jsonb_typeof(output->'evidence') = 'array' AND jsonb_typeof(output->'profile') = 'string'
      AND (
        (output->'evidence' = '[]'::jsonb AND output->>'profile' = '' AND output->'synthesis' = 'null'::jsonb) OR
        (output->'evidence' <> '[]'::jsonb AND output->>'profile' <> '' AND jsonb_typeof(output->'synthesis') = 'object')
      )
    SQL

    create_table :expression_profile_revisions do |t|
      t.references :expression_profile, null: false, index: false
      t.references :expression_profile_revision_eval, null: false, index: { unique: true }
      t.text :profile, null: false
      t.jsonb :annotations, null: false, default: []
      t.jsonb :expression_texts, null: false
      t.timestamps
    end

    add_check_constraint :expression_profile_revisions, "jsonb_typeof(annotations) = 'array'", name: "expression_profile_revisions_annotations"
    add_index :expression_profile_revisions, [ :expression_profile_id, :id ]
    add_foreign_key :expression_profile_revisions, :expression_profile_revision_evals,
      column: [ :expression_profile_id, :expression_profile_revision_eval_id ], primary_key: [ :expression_profile_id, :id ], on_delete: :cascade
  end
end
