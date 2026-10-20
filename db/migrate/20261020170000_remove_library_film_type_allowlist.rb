class RemoveLibraryFilmTypeAllowlist < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :library_films, "type = 'LibraryFilmWatched'", name: "library_films_supported_type"
  end
end
