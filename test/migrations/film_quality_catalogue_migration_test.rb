require "test_helper"
require Rails.root.join("db/migrate/20261029130000_create_film_quality_catalogue")
require Rails.root.join("db/migrate/20261020130000_create_films")

class FilmQualityCatalogueMigrationTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "fresh catalogue has direct quality relationships and no analysis storage" do
    connection = ActiveRecord::Base.connection
    schema = "catalogue_migration_#{Process.pid}"
    original_path = connection.schema_search_path
    connection.create_schema(schema)
    connection.schema_search_path = schema
    ActiveRecord::Migration.suppress_messages do
      CreateFilms.new.migrate(:up)
      CreateFilmQualityCatalogue.new.migrate(:up)
      assert_equal %w[film_qualities film_quality_evals films qualities quality_categories], connection.tables.sort
      assert_not connection.column_exists?(:qualities, :key)
      assert_not connection.column_exists?(:quality_categories, :key)
      assert connection.column_exists?(:qualities, :match_rule, :text)
      assert connection.column_exists?(:qualities, :not_sufficient, :text)
      assert connection.check_constraint_exists?(:qualities, name: "qualities_complete_definitions")
      assert connection.foreign_key_exists?(:qualities, :quality_categories, column: :quality_category_id)
      assert connection.foreign_key_exists?(:film_qualities, :qualities, column: :quality_id)
      assert connection.foreign_key_exists?(:film_qualities, :films, column: :film_id)
      assert connection.foreign_key_exists?(:film_qualities, :film_quality_evals, column: [ :film_quality_eval_id, :film_id ])
      assert_not connection.column_exists?(:film_qualities, :evidence_references)
      assert connection.foreign_key_exists?(:film_quality_evals, :films, column: :film_id)
      assert_equal %w[id film_id output application created_at updated_at], connection.columns(:film_quality_evals).map(&:name)
      assert_equal %w[id film_id quality_id film_quality_eval_id created_at updated_at], connection.columns(:film_qualities).map(&:name)
      assert connection.index_exists?(:film_qualities, [ :film_id, :quality_id ], unique: true)
      assert connection.column_exists?(:films, :wikipedia_context, :jsonb, null: false)
      assert connection.column_exists?(:films, :tmdb_metadata, :jsonb, null: false)
      assert connection.column_exists?(:films, :wikidata_id, :string, null: true)
      assert_equal %w[id title release_date tmdb_id tmdb_metadata wikidata_id wikipedia_context created_at updated_at], connection.columns(:films).map(&:name)
      assert connection.index_exists?(:films, :wikidata_id)
      assert connection.check_constraint_exists?(:films, name: "films_wikidata_id_format")
      assert_not connection.column_exists?(:films, :wikipedia_page_id)
      assert_not connection.column_exists?(:films, :metadata)
      assert_not connection.column_exists?(:films, :source_context)
      CreateFilmQualityCatalogue.new.migrate(:down)
      assert_equal [ "films" ], connection.tables
      assert connection.column_exists?(:films, :wikipedia_context)
    end
  ensure
    connection.schema_search_path = original_path if original_path
    connection.drop_schema(schema, if_exists: true) if schema
    connection.schema_cache.clear!
  end
end
