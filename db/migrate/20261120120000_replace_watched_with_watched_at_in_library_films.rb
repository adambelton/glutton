class ReplaceWatchedWithWatchedAtInLibraryFilms < ActiveRecord::Migration[8.1]
  def up
    add_column :library_films, :watched_at, :datetime
    execute <<~SQL
      UPDATE library_films SET watched_at = updated_at WHERE watched = TRUE
    SQL
    remove_column :library_films, :watched
  end

  def down
    add_column :library_films, :watched, :boolean, null: false, default: false
    execute <<~SQL
      UPDATE library_films SET watched = TRUE WHERE watched_at IS NOT NULL
    SQL
    remove_column :library_films, :watched_at
  end
end
