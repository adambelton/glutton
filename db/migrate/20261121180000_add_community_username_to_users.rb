class AddCommunityUsernameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :community_username, :string
    add_index :users, 'lower(community_username COLLATE "C")', unique: true, name: "users_community_username_unique"
  end
end
