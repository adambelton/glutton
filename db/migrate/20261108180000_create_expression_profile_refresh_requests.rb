class CreateExpressionProfileRefreshRequests < ActiveRecord::Migration[8.1]
  def up
    create_table :expression_profile_refresh_requests do |t|
      t.references :user, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.uuid :generation, default: -> { "gen_random_uuid()" }, null: false
      t.timestamps
    end

    execute <<~SQL
      INSERT INTO expression_profile_refresh_requests (user_id, created_at, updated_at)
      SELECT user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM (
        SELECT rating_films.user_id
        FROM rating_films
        JOIN (
          SELECT rating_film_id, MAX(id) AS id
          FROM ratings
          GROUP BY rating_film_id
        ) current_ratings ON current_ratings.rating_film_id = rating_films.id
        WHERE EXISTS (SELECT 1 FROM rating_expressions WHERE rating_id = current_ratings.id)
        UNION
        SELECT user_id FROM expression_profiles
      ) viewers
      ON CONFLICT (user_id) DO NOTHING
    SQL
  end

  def down
    drop_table :expression_profile_refresh_requests
  end
end
