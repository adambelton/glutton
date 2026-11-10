class CreateTasteProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :taste_profiles do |t|
      t.references :user, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.timestamps
    end

    create_table :taste_profile_revision_evals do |t|
      t.references :taste_profile, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.jsonb :input, null: false, default: []
      t.jsonb :output, null: false
      t.timestamps
    end

    add_index :taste_profile_revision_evals, [ :taste_profile_id, :id ], unique: true
    add_check_constraint :taste_profile_revision_evals, "jsonb_typeof(input) = 'array'", name: "taste_profile_revision_evals_input_calls"
    add_check_constraint :taste_profile_revision_evals, <<~SQL.squish, name: "taste_profile_revision_evals_completed_output"
      jsonb_typeof(output) = 'object' AND output ?& ARRAY['evidence', 'profile', 'synthesis', 'trace_id']
      AND jsonb_typeof(output->'evidence') = 'array' AND jsonb_typeof(output->'profile') = 'string'
      AND (
        (output->'evidence' = '[]'::jsonb AND output->>'profile' = '' AND output->'synthesis' = 'null'::jsonb) OR
        (output->'evidence' <> '[]'::jsonb AND output->>'profile' <> '' AND jsonb_typeof(output->'synthesis') = 'object')
      )
    SQL

    create_table :taste_profile_revisions do |t|
      t.references :taste_profile, null: false, index: false
      t.references :taste_profile_revision_eval, null: false, index: { unique: true }
      t.text :profile, null: false
      t.jsonb :annotations, null: false, default: []
      t.jsonb :notes, null: false
      t.timestamps
    end

    add_check_constraint :taste_profile_revisions, "jsonb_typeof(annotations) = 'array'", name: "taste_profile_revisions_annotations"
    add_index :taste_profile_revisions, [ :taste_profile_id, :id ]
    add_foreign_key :taste_profile_revisions, :taste_profile_revision_evals,
      column: [ :taste_profile_id, :taste_profile_revision_eval_id ], primary_key: [ :taste_profile_id, :id ], on_delete: :cascade
  end
end
