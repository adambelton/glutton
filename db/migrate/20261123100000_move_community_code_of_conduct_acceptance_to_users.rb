class MoveCommunityCodeOfConductAcceptanceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :community_code_of_conduct_version, :string
    add_column :users, :community_code_of_conduct_accepted_at, :datetime
    add_check_constraint :users,
      "(community_code_of_conduct_version IS NULL) = (community_code_of_conduct_accepted_at IS NULL)",
      name: "users_complete_community_code_of_conduct_acceptance"

    drop_table :community_code_of_conduct_acceptances do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string :code_version, null: false
      t.datetime :accepted_at, null: false
      t.index [ :user_id, :code_version ], unique: true, name: "community_conduct_acceptances_by_user_and_version"
    end
  end
end
