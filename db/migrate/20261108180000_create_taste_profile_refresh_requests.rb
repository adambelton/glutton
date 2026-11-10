class CreateTasteProfileRefreshRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :taste_profile_refresh_requests do |t|
      t.references :user, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.uuid :generation, default: -> { "gen_random_uuid()" }, null: false
      t.timestamps
    end
  end
end
