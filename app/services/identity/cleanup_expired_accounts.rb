module Identity
  class CleanupExpiredAccounts
    def self.call(batch_size: 100)
      unless batch_size.is_a?(Integer) && (1..1_000).cover?(batch_size)
        raise ArgumentError, "batch_size must be an integer from 1 to 1000"
      end

      counts = { guests_deleted: 0, pending_registrations_deleted: 0 }
      UserGuest.where(created_at: ..24.hours.ago).order(:created_at, :id).limit(batch_size).pluck(:id).each do |id|
        deleted = delete_guest(id)
        next if deleted.nil?

        counts[:guests_deleted] += 1
        counts[:pending_registrations_deleted] += deleted
      end

      pending_candidates(batch_size).each do |id, guest_user_id|
        counts[:pending_registrations_deleted] += delete_pending(id, guest_user_id)
      end
      counts
    end

    def self.delete_guest(id)
      UserGuest.transaction(requires_new: true) do
        guest = UserGuest.lock.find_by(id:)
        next if guest.nil? || guest.active?

        Session.where(user_id: id).delete_all
        pending_count = PendingRegistration.where(guest_user_id: id).delete_all
        guest.destroy!
        pending_count
      end
    end
    private_class_method :delete_guest

    def self.pending_candidates(batch_size)
      PendingRegistration.joins("LEFT JOIN users AS lifetime_owners ON lifetime_owners.id = pending_registrations.guest_user_id")
        .where("pending_registrations.created_at <= :cutoff OR lifetime_owners.created_at <= :cutoff", cutoff: 24.hours.ago)
        .order(:created_at, :id).limit(batch_size).pluck(:id, :guest_user_id)
    end
    private_class_method :pending_candidates

    def self.delete_pending(id, guest_user_id)
      PendingRegistration.transaction(requires_new: true) do
        # Match preparation, attachment and confirmation: owner before pending row.
        User.lock.find_by(id: guest_user_id) if guest_user_id.present?
        registration = PendingRegistration.lock.find_by(id:)
        next 0 if registration.nil? || registration.guest_user_id != guest_user_id || registration.expires_at > Time.current

        registration.destroy!
        1
      end
    end
    private_class_method :delete_pending
  end
end
