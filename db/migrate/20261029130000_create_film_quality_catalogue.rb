class CreateFilmQualityCatalogue < ActiveRecord::Migration[8.1]
  def change
    create_table :quality_categories do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.integer :maximum_qualities, null: false, default: 3
      t.decimal :weight, precision: 8, scale: 3, null: false, default: 1
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :quality_categories, :key, unique: true
    add_index :quality_categories, "lower(name)", unique: true, name: "quality_categories_name"
    add_check_constraint :quality_categories, "key ~ '^[a-z][a-z0-9_]*$'", name: "quality_categories_key"
    add_check_constraint :quality_categories, "name = btrim(name) AND name <> ''", name: "quality_categories_name_present"
    add_check_constraint :quality_categories, "maximum_qualities >= 0", name: "quality_categories_maximum"
    add_check_constraint :quality_categories, "weight >= 0 AND weight <> 'NaN'::numeric", name: "quality_categories_weight"

    create_table :qualities do |t|
      t.references :quality_category, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :qualities, "quality_category_id, lower(name)", unique: true, name: "qualities_category_name"
    add_check_constraint :qualities, "name = btrim(name) AND name <> ''", name: "qualities_name_present"

    create_table :film_qualities do |t|
      t.references :film, null: false, foreign_key: true
      t.references :quality, null: false, foreign_key: true
      t.jsonb :evidence_references, null: false
      t.timestamps
    end
    add_index :film_qualities, [ :film_id, :quality_id ], unique: true
    add_check_constraint :film_qualities,
      "jsonb_typeof(evidence_references) = 'array' AND jsonb_array_length(evidence_references) > 0",
      name: "film_qualities_evidence_present"
  end
end
