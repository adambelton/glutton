class AddDeletionReplayIdToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :deletion_replay_id, :uuid

    # Reproduce these IDs when migrating a backup taken before this change.
    execute <<~SQL
      UPDATE users
      SET deletion_replay_id = md5('glutton-account-recovery-v1:' || id::text || ':' ||
                            to_char(created_at, 'YYYY-MM-DD"T"HH24:MI:SS.US'))::uuid
    SQL

    change_column_default :users, :deletion_replay_id, from: nil, to: -> { "gen_random_uuid()" }
    change_column_null :users, :deletion_replay_id, false
    add_index :users, :deletion_replay_id, unique: true
  end

  def down
    remove_column :users, :deletion_replay_id
  end
end
