class AddFilmToCommunityPostNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    add_reference :community_post_notification_preferences, :film, foreign_key: { on_delete: :cascade }
    remove_index :community_post_notification_preferences, column: [ :post_id, :user_id ], unique: true
    add_index :community_post_notification_preferences, [ :post_id, :film_id, :user_id ], unique: true, nulls_not_distinct: true,
      name: "index_community_post_notification_preferences_on_scope"

    reversible do |direction|
      direction.down { execute "DELETE FROM community_post_notification_preferences WHERE film_id IS NOT NULL" }
    end
  end
end
