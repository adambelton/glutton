class CreateFilmAnalyses < ActiveRecord::Migration[8.1]
  def change
    create_table :film_qualities do |t|
      t.string :dimension, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :film_qualities, "dimension, lower(name)", unique: true, name: "film_qualities_dimension_name"
    add_check_constraint :film_qualities, "name = btrim(name) AND name <> ''", name: "film_qualities_name_present"
    add_check_constraint :film_qualities,
      "dimension IN ('emotional_character', 'tension_and_rhythm', 'engagement', 'relationships_and_stakes', " \
      "'intensity_and_explicitness', 'tone', 'resolution_and_aftermath')", name: "film_qualities_dimension"

    create_table :film_analyses do |t|
      t.references :film, null: false, foreign_key: true
      t.references :superseded_by, foreign_key: { to_table: :film_analyses }
      t.jsonb :content, null: false, default: {}
      t.jsonb :quality_candidates, null: false, default: []
      t.datetime :published_at
      t.datetime :superseded_at
      t.timestamps
    end
    add_index :film_analyses, :film_id, unique: true, where: "published_at IS NULL", name: "one_draft_analysis_per_film"
    add_index :film_analyses, :film_id, unique: true,
      where: "published_at IS NOT NULL AND superseded_at IS NULL", name: "one_active_analysis_per_film"
    add_check_constraint :film_analyses, "jsonb_typeof(content) = 'object'",
      name: "film_analyses_documents"
    add_check_constraint :film_analyses,
      "(superseded_at IS NULL AND superseded_by_id IS NULL) OR " \
      "(published_at IS NOT NULL AND superseded_at > published_at AND superseded_by_id IS NOT NULL AND superseded_by_id <> id)",
      name: "film_analyses_valid_supersession"

    add_check_constraint :film_analyses, "jsonb_typeof(quality_candidates) = 'array'", name: "film_analyses_quality_candidates_array"

    create_table :analysis_qualities do |t|
      t.references :film_analysis, null: false, foreign_key: true
      t.references :film_quality, null: false, foreign_key: true
      t.jsonb :evidence_references, null: false
      t.timestamps
    end
    add_index :analysis_qualities, [ :film_analysis_id, :film_quality_id ], unique: true
    add_check_constraint :analysis_qualities,
      "jsonb_typeof(evidence_references) = 'array' AND jsonb_array_length(evidence_references) > 0",
      name: "analysis_qualities_evidence_present"
  end
end
