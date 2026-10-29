class CreateFilms < ActiveRecord::Migration[8.1]
  def change
    create_table :films do |t|
      t.string :title, null: false
      t.date :release_date
      t.jsonb :metadata, null: false, default: {}
      t.bigint :tmdb_id
      t.jsonb :source_context, null: false, default: {}
      t.timestamps
    end

    add_check_constraint :films, "jsonb_typeof(source_context) = 'object'", name: "films_source_context_object"
    add_index :films, :tmdb_id, unique: true
    add_check_constraint :films, "jsonb_typeof(metadata) = 'object'", name: "films_metadata_is_object"
  end
end
