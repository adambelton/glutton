class AddCommunityAvatarPresetToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :community_avatar_preset, :string
  end
end
