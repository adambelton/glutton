require "test_helper"

module Identity
  class CleanupExpiredAccountsTest < ActiveSupport::TestCase
    def pending(guest: nil, created_at: Time.current)
      PendingRegistration.create!(email_address: "private-cleanup@example.test", password: "private password phrase",
        password_confirmation: "private password phrase", guest_user: guest, created_at:)
    end

    def cleanup(**attributes)
      CleanupExpiredAccounts.call(**attributes)
    end

    test "guest expiry is exact and deletes dependent identities without touching other subtypes" do
      freeze_time
      guest = UserGuest.create!
      2.times { Session.create!(user: guest) }
      linked = pending(guest:)
      registered = UserRegistered.create!(email_address: "retained@example.test", password: "private password phrase",
        password_confirmation: "private password phrase", email_confirmed_at: Time.current)
      registered_session = Session.create!(user: registered)
      deleted = UserGuest.create!
      deleted_session = Session.create!(user: deleted)
      deleted.update_columns(type: "UserDeleted")
      base = User.create!(type: "User")
      base_session = Session.create!(user: base)
      travel 24.hours - 1.second
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 0 }, cleanup)
      travel 1.second
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 1 }, cleanup)
      assert_nil User.find_by(id: guest.id)
      assert_nil PendingRegistration.find_by(id: linked.id)
      assert_not Session.exists?(user_id: guest.id)
      assert registered_session.active?
      assert Session.exists?(deleted_session.id)
      assert base_session.active?
      [ registered, deleted, base ].each { |record| assert User.exists?(record.id) }
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 0 }, cleanup)
    end

    test "pending deadlines preserve active guests and ignore one hour token expiry" do
      freeze_time
      direct = pending
      travel 1.hour
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 0 }, cleanup)
      guest = UserGuest.create!
      session = Session.create!(user: guest)
      linked = pending(guest:)
      travel 23.hours
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 1 }, cleanup)
      assert_not PendingRegistration.exists?(direct.id)
      assert PendingRegistration.exists?(linked.id)
      assert session.active?
      travel 1.hour
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 1 }, cleanup)
    end

    test "linked pending is capped by the older guest deadline" do
      freeze_time
      guest = UserGuest.create!
      travel 23.hours
      linked = pending(guest:)
      assert_equal Time.current + 1.hour, linked.expires_at
      travel 1.hour
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 1 }, cleanup)
    end

    test "expired pending alone preserves an active linked guest and session" do
      guest = UserGuest.create!
      session = Session.create!(user: guest)
      record = pending(guest:, created_at: 25.hours.ago)
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 1 }, cleanup)
      assert session.active?
      assert User.exists?(guest.id)
      assert_not PendingRegistration.exists?(record.id)
    end

    test "candidate limits use oldest then id for each category" do
      freeze_time
      guests = 3.times.map { UserGuest.create!(created_at: 25.hours.ago) }
      older = UserGuest.create!(created_at: 26.hours.ago)
      requests = 3.times.map { pending(created_at: 25.hours.ago) }
      older_request = pending(created_at: 26.hours.ago)
      assert_equal({ guests_deleted: 2, pending_registrations_deleted: 2 }, cleanup(batch_size: 2))
      [ older, guests.first ].each { |record| assert_not User.exists?(record.id) }
      [ older_request, requests.first ].each { |record| assert_not PendingRegistration.exists?(record.id) }
      assert_equal 2, UserGuest.count
      assert_equal 2, PendingRegistration.count
      assert_equal({ guests_deleted: 2, pending_registrations_deleted: 2 }, cleanup(batch_size: 2))
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 0 }, cleanup)
    end

    test "invalid batch sizes fail before writes" do
      guest = UserGuest.create!(created_at: 25.hours.ago)
      [ nil, "1", 1.0, 0, -1, 1_001, true ].each do |batch_size|
        assert_raises(ArgumentError) { cleanup(batch_size:) }
        assert User.exists?(guest.id)
      end
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 0 }, cleanup(batch_size: 1_000))
    end

    test "dependent deletion failure restores sessions and pending rows" do
      freeze_time
      guest = UserGuest.create!
      session = Session.create!(user: guest)
      record = pending(guest:)
      travel 24.hours
      callback = ->(*args) do
        event = ActiveSupport::Notifications::Event.new(*args)
        raise IOError, "simulated deletion failure" if event.payload[:sql].match?(/DELETE FROM "pending_registrations"/)
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        assert_raises(IOError) { cleanup }
      end
      assert User.exists?(guest.id)
      assert Session.exists?(session.id)
      assert PendingRegistration.exists?(record.id)
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 1 }, cleanup)
    end

    test "foreign key rejection restores candidate dependents but preserves earlier deletion" do
      freeze_time
      first = UserGuest.create!(created_at: 2.seconds.ago)
      blocked = UserGuest.create!
      session = Session.create!(user: blocked)
      record = pending(guest: blocked)
      connection = ActiveRecord::Base.connection
      # Test-only unknown dependent proves cleanup cannot bypass future domain constraints.
      connection.execute("CREATE TABLE retention_test_blockers (user_id bigint REFERENCES users(id))")
      connection.execute("INSERT INTO retention_test_blockers (user_id) VALUES (#{Integer(blocked.id)})")
      travel 24.hours
      assert_raises(ActiveRecord::InvalidForeignKey) { cleanup }
      assert_not User.exists?(first.id)
      assert User.exists?(blocked.id)
      assert Session.exists?(session.id)
      assert PendingRegistration.exists?(record.id)
      connection.execute("DELETE FROM retention_test_blockers")
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 1 }, cleanup)
    ensure
      connection&.execute("DROP TABLE IF EXISTS retention_test_blockers")
    end
  end
end
