class CreateRecommendationFilms < ActiveRecord::Migration[8.1]
  def change
    create_table :recommendation_films do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :film, null: false, foreign_key: true
      t.boolean :suppressed, null: false, default: false
      t.string :response
      t.datetime :recommended_at
      t.timestamps
      t.index [ :user_id, :film_id ], unique: true
      t.check_constraint "response IN ('accepted', 'rejected')", name: "recommendation_films_response"
      t.check_constraint "suppressed OR response IS NOT NULL OR recommended_at IS NOT NULL", name: "recommendation_films_selection"
    end
  end
end
