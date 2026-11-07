class CreateRatingQualities < ActiveRecord::Migration[8.1]
  def up
    create_table :rating_qualities do |t|
      t.references :rating, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :quality, null: false, foreign_key: true
      t.string :classification, null: false
      t.integer :score, null: false
      t.timestamps

      t.index [ :rating_id, :quality_id ], unique: true
    end

    execute <<~SQL
      INSERT INTO rating_qualities (rating_id, quality_id, classification, score, created_at, updated_at)
      SELECT ratings.id, film_qualities.quality_id, 'unexpressed',
        CASE ratings.value
          WHEN 'brilliant' THEN 2
          WHEN 'pretty_good' THEN 1
          WHEN 'not_for_me' THEN -1
          WHEN 'garbage' THEN -2
        END,
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM ratings
      JOIN (SELECT MAX(id) AS id FROM ratings GROUP BY rating_film_id) current_ratings
        ON current_ratings.id = ratings.id
      JOIN rating_films ON rating_films.id = ratings.rating_film_id
      JOIN film_qualities ON film_qualities.film_id = rating_films.film_id
    SQL
  end

  def down
    drop_table :rating_qualities
  end
end
