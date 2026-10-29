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
      assert_equal %w[film_qualities films qualities quality_categories], connection.tables.sort
      assert connection.foreign_key_exists?(:qualities, :quality_categories, column: :quality_category_id)
      assert connection.foreign_key_exists?(:film_qualities, :qualities, column: :quality_id)
      assert connection.foreign_key_exists?(:film_qualities, :films, column: :film_id)
      assert connection.index_exists?(:film_qualities, [ :film_id, :quality_id ], unique: true)
      assert connection.column_exists?(:films, :source_context, :jsonb, null: false)
      CreateFilmQualityCatalogue.new.migrate(:down)
      assert_equal [ "films" ], connection.tables
      assert connection.column_exists?(:films, :source_context)
    end
  ensure
    connection.schema_search_path = original_path if original_path
    connection.drop_schema(schema, if_exists: true) if schema
    connection.schema_cache.clear!
  end
end
