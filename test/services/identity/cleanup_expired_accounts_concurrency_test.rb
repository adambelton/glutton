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
      PendingRegistration.where(id: @pending_ids).delete_all
      Session.where(user_id: @user_ids).delete_all
      User.where(id: @user_ids).delete_all
    end

    def guest
      UserGuest.create!.tap { |record| @user_ids << record.id }
    end

    def pending(guest: nil)
      PrepareRegistration.call(email_address: "retention-race@example.test", guest_user_id: guest&.id,
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
      token = RegistrationConfirmation.token_for(pending_registration_id: request.id)
      contender = nil
      session = User.transaction do
        owner.lock!
        completed = CompleteRegistration.call(token:)
        # Cleanup sees the still-uncommitted guest version after its deadline.
        travel UserGuest::EXPIRY_DURATION
        contender = blocked_operation { CleanupExpiredAccounts.call }
        completed
      end
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 0 }, Timeout.timeout(5) { contender.value })
      assert (User.find(owner.id)).can_reset_password?
      assert session.active?
      assert_not PendingRegistration.exists?(request.id)
    end

    test "overlapping cleanup runs count guest and linked pending only once" do
      freeze_time
      owner = guest
      request = pending(guest: owner)
      Session.create!(user: owner)
      token = RegistrationConfirmation.token_for(pending_registration_id: request.id)
      travel UserGuest::EXPIRY_DURATION
      contender = nil
      result = User.transaction do
        owner.lock!
        contender = blocked_operation { CleanupExpiredAccounts.call }
        CleanupExpiredAccounts.call
      end
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 1 }, result)
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 0 }, Timeout.timeout(5) { contender.value })
      assert_not User.exists?(owner.id)
      assert_not Session.exists?(user_id: owner.id)
      assert_not PendingRegistration.exists?(request.id)
      assert_raises(RegistrationUnavailable) { CompleteRegistration.call(token:) }
    end

    test "overlapping direct pending cleanup counts once" do
      freeze_time
      request = pending
      travel_to request.expires_at
      contender = nil
      result = PendingRegistration.transaction do
        request.lock!
        contender = blocked_operation { CleanupExpiredAccounts.call }
        CleanupExpiredAccounts.call
      end
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 1 }, result)
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 0 }, Timeout.timeout(5) { contender.value })
    end

    test "attachment before deadline and cleanup after deadline use compatible lock order" do
      freeze_time
      owner = guest
      travel UserGuest::EXPIRY_DURATION - 1.second
      request = pending
      contender = nil
      User.transaction do
        owner.lock!
        AttachRegistration.call(pending_registration_id: request.id, guest_user_id: owner.id)
        travel 1.second
        contender = blocked_operation { CleanupExpiredAccounts.call }
      end
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 1 }, Timeout.timeout(5) { contender.value })
      assert_not User.exists?(owner.id)
      assert_not PendingRegistration.exists?(request.id)
    end

    test "linked pending cleanup waits on owner before pending and rechecks changed linkage" do
      freeze_time
      owner = guest
      request = pending(guest: owner)
      # The pending row may expire independently of its still-active guest.
      request.update_columns(created_at: (PendingRegistration::EXPIRY_DURATION + 1.second).ago)
      contender = nil
      User.transaction do
        owner.lock!
        contender = blocked_operation { CleanupExpiredAccounts.call }
        request.lock!
        request.update!(guest_user_id: nil)
      end
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 0 }, Timeout.timeout(5) { contender.value })
      assert User.exists?(owner.id)
      assert PendingRegistration.exists?(request.id)
      assert_equal({ guests_deleted: 0, pending_registrations_deleted: 1 }, CleanupExpiredAccounts.call)
    end

    test "candidate failure does not roll back earlier committed candidates" do
      freeze_time
      first = guest
      travel 1.second
      blocked = guest
      Session.create!(user: blocked)
      travel UserGuest::EXPIRY_DURATION
      original = UserGuest.instance_method(:destroy!)
      blocked_id = blocked.id
      UserGuest.define_method(:destroy!) do
        raise IOError, "simulated failure" if id == blocked_id
        original.bind_call(self)
      end
      assert_raises(IOError) { CleanupExpiredAccounts.call }
      visible = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          [ User.exists?(first.id), User.exists?(blocked.id), Session.exists?(user_id: blocked.id) ]
        end
      end.value
      assert_equal [ false, true, true ], visible
    ensure
      UserGuest.define_method(:destroy!, original) if original
    end
  end
end
