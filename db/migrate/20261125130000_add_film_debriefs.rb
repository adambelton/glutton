class AddFilmDebriefs < ActiveRecord::Migration[8.1]
  def change
    add_reference :posts, :film, foreign_key: true, index: { unique: true, where: "film_id IS NOT NULL" }
    add_check_constraint :posts, <<~SQL.squish, name: :film_debriefs_require_film_without_author
      (type = 'Community::PostFilmDebrief' AND film_id IS NOT NULL AND author_id IS NULL AND deletable_author_id IS NULL)
      OR (type <> 'Community::PostFilmDebrief' AND film_id IS NULL)
    SQL
  end
end
