require "test_helper"
require "timeout"

module Identity
  class CleanupExpiredAccountsConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      @threads = []
      @user_ids = []
      @pending_ids = []
    end

    teardown do
      @threads.each { |thread| thread.kill if thread.alive?; thread.join }
      Identity::PendingRegistration.where(id: @pending_ids).delete_all
      Identity::Session.where(user_id: @user_ids).delete_all
      Identity::User.where(id: @user_ids).delete_all
    end

    def guest
      Identity::UserGuest.create!.tap { |record| @user_ids << record.id }
    end

    def pending(guest: nil)
      Registration::PrepareRegistration.call(email_address: "retention-race@example.test", guest_user_id: guest&.id,
        password: "private password phrase", password_confirmation: "private password phrase")
        .tap { |record| @pending_ids << record.id }
    end

    def blocked_operation(&operation)
      ready = Queue.new
      thread = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          ready << connection.select_value("SELECT pg_backend_pid()")
          operation.call
        end
      end
      @threads << thread
      pid = Timeout.timeout(5) { ready.pop }
      connection = ActiveRecord::Base.connection
      Timeout.timeout(5) do
        until connection.uncached { connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)}))") }.positive?
          sleep 0.01
        end
      end
      thread
    end

    test "confirmation committed before waiting cleanup preserves registered identity and session" do
      freeze_time
      owner = guest
      request = pending(guest: owner)
      token = Registration::RegistrationConfirmation.token_for(pending_registration_id: request.id)
      contender = nil
      session = Identity::User.transaction do
        owner.lock!
        completed = Registration::CompleteRegistration.call(token:)
        # Cleanup sees the still-uncommitted guest version after its deadline.
        travel Identity::UserGuest::EXPIRY_DURATION
        contender = blocked_operation { AccountAdministration::CleanupExpiredAccounts.call }
        completed
      end
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 0 }, Timeout.timeout(5) { contender.value })
      assert (Identity::User.find(owner.id)).can_reset_password?
      assert session.active?
      assert_not Identity::PendingRegistration.exists?(request.id)
    end

    test "overlapping cleanup runs count guest and linked pending only once" do
      freeze_time
      owner = guest
      request = pending(guest: owner)
      Identity::Session.create!(user: owner)
      token = Registration::RegistrationConfirmation.token_for(pending_registration_id: request.id)
      travel Identity::UserGuest::EXPIRY_DURATION
      contender = nil
      result = Identity::User.transaction do
        owner.lock!
        contender = blocked_operation { AccountAdministration::CleanupExpiredAccounts.call }
        AccountAdministration::CleanupExpiredAccounts.call
      end
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 1 }, result)
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 0 }, Timeout.timeout(5) { contender.value })
      assert_not Identity::User.exists?(owner.id)
      assert_not Identity::Session.exists?(user_id: owner.id)
      assert_not Identity::PendingRegistration.exists?(request.id)
      assert_raises(Errors::RegistrationUnavailable) { Registration::CompleteRegistration.call(token:) }
    end

    test "overlapping direct pending cleanup counts once" do
      freeze_time
      request = pending
      travel_to request.expires_at
      contender = nil
      result = Identity::PendingRegistration.transaction do
        request.lock!
        contender = blocked_operation { AccountAdministration::CleanupExpiredAccounts.call }
        AccountAdministration::CleanupExpiredAccounts.call
      end
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 1 }, result)
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 0 }, Timeout.timeout(5) { contender.value })
    end

    test "attachment before deadline and cleanup after deadline use compatible lock order" do
      freeze_time
      owner = guest
      travel Identity::UserGuest::EXPIRY_DURATION - 1.second
      request = pending
      contender = nil
      Identity::User.transaction do
        owner.lock!
        Registration::AttachRegistration.call(pending_registration_id: request.id, guest_user_id: owner.id)
        travel 1.second
        contender = blocked_operation { AccountAdministration::CleanupExpiredAccounts.call }
      end
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 1 }, Timeout.timeout(5) { contender.value })
      assert_not Identity::User.exists?(owner.id)
      assert_not Identity::PendingRegistration.exists?(request.id)
    end

    test "linked pending cleanup waits on owner before pending and rechecks changed linkage" do
      freeze_time
      owner = guest
      request = pending(guest: owner)
      # The pending row may expire independently of its still-active guest.
      request.update_columns(created_at: (Identity::PendingRegistration::EXPIRY_DURATION + 1.second).ago)
      contender = nil
      Identity::User.transaction do
        owner.lock!
        contender = blocked_operation { AccountAdministration::CleanupExpiredAccounts.call }
        request.lock!
        request.update!(guest_user_id: nil)
      end
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 0 }, Timeout.timeout(5) { contender.value })
      assert Identity::User.exists?(owner.id)
      assert Identity::PendingRegistration.exists?(request.id)
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 1 }, AccountAdministration::CleanupExpiredAccounts.call)
    end

    test "candidate failure does not roll back earlier committed candidates" do
      freeze_time
      first = guest
      travel 1.second
      blocked = guest
      Identity::Session.create!(user: blocked)
      travel Identity::UserGuest::EXPIRY_DURATION
      original = Identity::UserGuest.instance_method(:destroy_with_activity!)
      blocked_id = blocked.id
      Identity::UserGuest.define_method(:destroy_with_activity!) do
        raise IOError, "simulated failure" if id == blocked_id
        original.bind_call(self)
      end
      assert_raises(IOError) { AccountAdministration::CleanupExpiredAccounts.call }
      visible = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          [ Identity::User.exists?(first.id), Identity::User.exists?(blocked.id), Identity::Session.exists?(user_id: blocked.id) ]
        end
      end.value
      assert_equal [ false, true, true ], visible
    ensure
      Identity::UserGuest.define_method(:destroy_with_activity!, original) if original
    end
  end
end
