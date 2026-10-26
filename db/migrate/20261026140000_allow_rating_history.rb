class AllowRatingHistory < ActiveRecord::Migration[8.1]
  def up
    remove_index :ratings, :rating_film_id
    add_index :ratings, [ :rating_film_id, :id ]
  end

  def down
    remove_index :ratings, [ :rating_film_id, :id ]
    add_index :ratings, :rating_film_id, unique: true
  end
end
