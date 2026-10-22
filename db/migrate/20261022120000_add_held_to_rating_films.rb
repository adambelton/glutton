class AddHeldToRatingFilms < ActiveRecord::Migration[8.1]
  def change
    add_column :rating_films, :held, :boolean, null: false, default: false
  end
end
