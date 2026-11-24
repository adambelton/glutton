class CreateCommunityEndorsementComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :post, null: false, foreign_key: { on_delete: :cascade }
      t.references :film_endorsement, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end

    create_table :comment_contents do |t|
      t.references :comment, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.references :author, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.text :body, null: false
      t.timestamps
    end
  end
end
