namespace :identity do
  desc "Delete one bounded batch of expired guests and pending registrations"
  task cleanup_expired: :environment do
    counts = Identity::AccountAdministration::CleanupExpiredAccounts.call
    puts "guests_deleted=#{counts.fetch(:guests_deleted)} pending_registrations_deleted=#{counts.fetch(:pending_registrations_deleted)}"
  rescue StandardError => error
    # Persistence exceptions may contain private row values. Do not print them.
    warn "Identity cleanup failed (#{error.class.name}); earlier candidates may have committed. Safe to rerun."
    exit 1
  end

  desc "Replay recorded account deletions into an isolated recovery database"
  task replay_account_deletions: :environment do
    expected_database = ENV["ACCOUNT_DELETION_RESTORE_DATABASE"]
    database = ActiveRecord::Base.connection_db_config.database
    abort "Set ACCOUNT_DELETION_RESTORE_DATABASE to the isolated recovery database name." unless
      expected_database.present? && database == expected_database

    log = Identity::AccountAdministration::DeletionLog.reader
    count = Identity::AccountAdministration::ReplayAccountDeletions.new(deletion_log: log).call
    puts "accounts_deleted=#{count}"
  rescue StandardError => error
    warn "Deletion replay failed (#{error.class.name}). Resolve the failure and rerun before using the restored database."
    exit 1
  end
end
