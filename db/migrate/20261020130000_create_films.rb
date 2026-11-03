class CreateFilms < ActiveRecord::Migration[8.1]
  def change
    create_table :films do |t|
      t.string :title, null: false
      t.date :release_date
      t.bigint :tmdb_id
      t.jsonb :tmdb_metadata, null: false, default: {}
      t.string :wikidata_id
      t.jsonb :wikipedia_context, null: false, default: {}
      t.timestamps
    end

    add_check_constraint :films, "jsonb_typeof(wikipedia_context) = 'object'", name: "films_wikipedia_context_object"
    add_index :films, :tmdb_id, unique: true
    add_index :films, :wikidata_id
    add_check_constraint :films, "wikidata_id IS NULL OR wikidata_id ~ '^Q[1-9][0-9]*$'", name: "films_wikidata_id_format"
    add_check_constraint :films, "jsonb_typeof(tmdb_metadata) = 'object'", name: "films_tmdb_metadata_is_object"
  end
end
