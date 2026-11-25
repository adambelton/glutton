class PreserveCurationRepliesOnAccountClosure < ActiveRecord::Migration[8.1]
  def up
    change_column_null :film_endorsements, :user_id, true
    remove_foreign_key :film_endorsements, :users
    add_foreign_key :film_endorsements, :users, on_delete: :nullify
    # Account removal can clear the endorser before its authored post cascades.
    remove_foreign_key :film_endorsements, :posts
    add_foreign_key :film_endorsements, :posts, on_delete: :cascade, deferrable: :deferred
  end

  def down
    if select_value("SELECT EXISTS (SELECT 1 FROM film_endorsements WHERE user_id IS NULL)")
      raise ActiveRecord::IrreversibleMigration, "Anonymous endorsements may anchor surviving replies"
    end

    remove_foreign_key :film_endorsements, :users
    add_foreign_key :film_endorsements, :users, on_delete: :cascade
    remove_foreign_key :film_endorsements, :posts
    add_foreign_key :film_endorsements, :posts, on_delete: :cascade
    change_column_null :film_endorsements, :user_id, false
  end
end
