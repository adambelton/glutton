namespace :identity do
  desc "Delete one bounded batch of expired guests and pending registrations"
  task cleanup_expired: :environment do
    counts = Identity::CleanupExpiredAccounts.call
    puts "guests_deleted=#{counts.fetch(:guests_deleted)} pending_registrations_deleted=#{counts.fetch(:pending_registrations_deleted)}"
  rescue StandardError => error
    # Persistence exceptions may contain private row values. Do not print them.
    warn "Identity cleanup failed (#{error.class.name}); earlier candidates may have committed. Safe to rerun."
    exit 1
  end
end
