class AddCommunityCurationNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :community_curation_notification_preferences do |t|
      t.references :user, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.boolean :authored_curations, null: false, default: true
      t.boolean :endorsed_film_comments, null: false, default: false
      t.timestamps
    end
  end
end
