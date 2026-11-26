class RenameCommunityPostPromptToDescription < ActiveRecord::Migration[8.1]
  def change
    rename_column :posts, :prompt, :description
  end
end
