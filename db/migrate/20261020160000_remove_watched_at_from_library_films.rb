class RemoveWatchedAtFromLibraryFilms < ActiveRecord::Migration[8.1]
  def change
    remove_column :library_films, :watched_at, :datetime, null: false
  end
end
