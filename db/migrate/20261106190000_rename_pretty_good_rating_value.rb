class RenamePrettyGoodRatingValue < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :ratings,
      "value IN ('brilliant', 'i_enjoyed_that', 'not_for_me', 'garbage')", name: "ratings_value_allowed"
    add_check_constraint :ratings,
      "value IN ('brilliant', 'pretty_good', 'not_for_me', 'garbage')", name: "ratings_value_allowed"
  end
end
