class CreateCommunityCodeOfConductAcceptances < ActiveRecord::Migration[8.1]
  def change
    create_table :community_code_of_conduct_acceptances do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string :code_version, null: false
      t.datetime :accepted_at, null: false

      t.index [ :user_id, :code_version ], unique: true, name: "community_conduct_acceptances_by_user_and_version"
    end
  end
end
