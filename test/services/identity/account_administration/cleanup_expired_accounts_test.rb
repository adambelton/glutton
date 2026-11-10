require "test_helper"

module Identity
  class CleanupExpiredAccountsTest < ActiveSupport::TestCase
    def pending(guest: nil, created_at: Time.current)
      Identity::PendingRegistration.create!(email_address: "private-cleanup@example.test", password: "private password phrase",
        password_confirmation: "private password phrase", guest_user: guest, created_at:)
    end

    def cleanup(**attributes)
      AccountAdministration::CleanupExpiredAccounts.call(**attributes)
    end

    test "guest expiry is exact and deletes dependent identities without touching other subtypes" do
      freeze_time
      guest = Identity::UserGuest.create!
      2.times { Identity::Session.create!(user: guest) }
      registered = Identity::UserRegistered.create!(email_address: "retained@example.test", password: "private password phrase",
        password_confirmation: "private password phrase", email_confirmed_at: Time.current)
      registered_session = Identity::Session.create!(user: registered)
      deleted = Identity::UserGuest.create!
      deleted_session = Identity::Session.create!(user: deleted)
      deleted.update_columns(type: "UserDeleted")
      base = Identity::User.find(Identity::User.insert_all!([ { type: "User" } ]).rows.first.first)
      base_session = Identity::Session.create!(user: base)
      travel Identity::UserGuest::EXPIRY_DURATION - 1.second
      linked = pending(guest:)
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 0 }, cleanup)
      travel 1.second
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 1 }, cleanup)
      assert_nil Identity::User.find_by(id: guest.id)
      assert_nil Identity::PendingRegistration.find_by(id: linked.id)
      assert_not Identity::Session.exists?(user_id: guest.id)
      assert registered_session.active?
      assert Identity::Session.exists?(deleted_session.id)
      assert base_session.active?
      [ registered, deleted, base ].each { |record| assert Identity::User.exists?(record.id) }
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 0 }, cleanup)
    end

    test "pending deadlines preserve active guests and linked pending requests" do
      freeze_time
      direct = pending
      travel Identity::PendingRegistration::EXPIRY_DURATION / 2
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 0 }, cleanup)
      travel_to direct.expires_at - 1.second
      guest = Identity::UserGuest.create!
      session = Identity::Session.create!(user: guest)
      linked = pending(guest:)
      travel 1.second
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 1 }, cleanup)
      assert_not Identity::PendingRegistration.exists?(direct.id)
      assert Identity::PendingRegistration.exists?(linked.id)
      assert session.active?
      travel_to guest.created_at + Identity::UserGuest::EXPIRY_DURATION
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 1 }, cleanup)
    end

    test "guest inactivity invalidates linked registration before its own deadline" do
      freeze_time
      guest = Identity::UserGuest.create!
      travel Identity::UserGuest::EXPIRY_DURATION - 1.second
      linked = pending(guest:)
      assert_equal Time.current + Identity::PendingRegistration::EXPIRY_DURATION, linked.expires_at
      travel 1.second
      assert_not linked.active?
      assert linked.expires_at > Time.current
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 1 }, cleanup)
    end

    test "expired pending alone preserves an active linked guest and session" do
      guest = Identity::UserGuest.create!
      session = Identity::Session.create!(user: guest)
      record = pending(guest:, created_at: (Identity::PendingRegistration::EXPIRY_DURATION + 1.second).ago)
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 1 }, cleanup)
      assert session.active?
      assert Identity::User.exists?(guest.id)
      assert_not Identity::PendingRegistration.exists?(record.id)
    end

    test "candidate limits use oldest then id for each category" do
      freeze_time
      guests = 3.times.map { Identity::UserGuest.create!(created_at: (Identity::UserGuest::EXPIRY_DURATION + 1.hour).ago) }
      older = Identity::UserGuest.create!(created_at: (Identity::UserGuest::EXPIRY_DURATION + 2.hours).ago)
      requests = 3.times.map { pending(created_at: (Identity::PendingRegistration::EXPIRY_DURATION + 1.second).ago) }
      older_request = pending(created_at: (Identity::PendingRegistration::EXPIRY_DURATION + 2.seconds).ago)
      assert_equal({ guests_deleted: 2, pending_registrations_deleted: 2 }, cleanup(batch_size: 2))
      [ older, guests.first ].each { |record| assert_not Identity::User.exists?(record.id) }
      [ older_request, requests.first ].each { |record| assert_not Identity::PendingRegistration.exists?(record.id) }
      assert_equal 2, Identity::UserGuest.count
      assert_equal 2, Identity::PendingRegistration.count
      assert_equal({ guests_deleted: 2, pending_registrations_deleted: 2 }, cleanup(batch_size: 2))
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 0 }, cleanup)
    end

    test "invalid batch sizes fail before writes" do
      guest = Identity::UserGuest.create!(created_at: (Identity::UserGuest::EXPIRY_DURATION + 1.hour).ago)
      [ nil, "1", 1.0, 0, -1, 1_001, true ].each do |batch_size|
        assert_raises(ArgumentError) { cleanup(batch_size:) }
        assert Identity::User.exists?(guest.id)
      end
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 0 }, cleanup(batch_size: 1_000))
    end

    test "dependent deletion failure restores sessions and pending rows" do
      freeze_time
      guest = Identity::UserGuest.create!
      session = Identity::Session.create!(user: guest)
      record = pending(guest:)
      travel Identity::UserGuest::EXPIRY_DURATION
      callback = ->(*args) do
        event = ActiveSupport::Notifications::Event.new(*args)
        raise IOError, "simulated deletion failure" if event.payload[:sql].match?(/DELETE FROM "pending_registrations"/)
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        assert_raises(IOError) { cleanup }
      end
      assert Identity::User.exists?(guest.id)
      assert Identity::Session.exists?(session.id)
      assert Identity::PendingRegistration.exists?(record.id)
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 1 }, cleanup)
    end

    test "foreign key rejection restores candidate dependents but preserves earlier deletion" do
      freeze_time
      first = Identity::UserGuest.create!(created_at: 2.seconds.ago)
      blocked = Identity::UserGuest.create!
      session = Identity::Session.create!(user: blocked)
      record = pending(guest: blocked)
      connection = ActiveRecord::Base.connection
      # Test-only unknown dependent proves cleanup cannot bypass future domain constraints.
      connection.execute("CREATE TABLE retention_test_blockers (user_id bigint REFERENCES users(id))")
      connection.execute("INSERT INTO retention_test_blockers (user_id) VALUES (#{Integer(blocked.id)})")
      travel Identity::UserGuest::EXPIRY_DURATION
      assert_raises(ActiveRecord::InvalidForeignKey) { cleanup }
      assert_not Identity::User.exists?(first.id)
      assert Identity::User.exists?(blocked.id)
      assert Identity::Session.exists?(session.id)
      assert Identity::PendingRegistration.exists?(record.id)
      connection.execute("DELETE FROM retention_test_blockers")
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 1 }, cleanup)
    ensure
      connection&.execute("DROP TABLE IF EXISTS retention_test_blockers")
    end
  end
end
