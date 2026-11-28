class CreateCommunityNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :community_film_debrief_notification_preferences do |t|
      t.references :user, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.boolean :brilliant, :pretty_good, :not_for_me, :garbage, :unrated, null: false, default: false
      t.timestamps
    end

    create_table :community_discussion_notification_preferences do |t|
      t.references :user, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.boolean :direct_replies, null: false, default: true
      t.timestamps
    end

    create_table :community_post_notification_preferences do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :post, null: false, foreign_key: { on_delete: :cascade }
      t.string :mode, null: false
      t.timestamps
      t.index [ :post_id, :user_id ], unique: true
      t.check_constraint "mode IN ('follow', 'mute')", name: "community_post_notification_mode"
    end

    create_table :community_notifications do |t|
      t.references :recipient, null: false, index: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :comment_content, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :read_at
      t.timestamps
      t.index [ :recipient_id, :comment_content_id ], unique: true
      t.index [ :recipient_id, :id ]
      t.index :recipient_id, where: "read_at IS NULL", name: "index_community_notifications_unread"
    end
  end
end
