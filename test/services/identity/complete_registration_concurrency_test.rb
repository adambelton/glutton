require "test_helper"
require "timeout"

module Identity
  class CompleteRegistrationConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    def prepare(email:, guest: nil)
      PrepareRegistration.call(email_address: email, guest_user_id: guest&.id,
        password: "a long password phrase", password_confirmation: "a long password phrase")
    end

    def token_for(record)
      RegistrationConfirmation.token_for(pending_registration_id: record.id)
    end

    def blocked_operation(operation)
      ready = Queue.new
      thread = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          ready << connection.select_value("SELECT pg_backend_pid()")
          begin
            operation.call
          rescue RegistrationUnavailable => error
            error
          end
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

    setup do
      @threads = []
      @pending_ids = []
      @user_ids = []
    end

    teardown do
      @threads.each { |thread| thread.kill if thread.alive?; thread.join }
      PendingRegistration.where(id: @pending_ids).delete_all
      Session.where(user_id: @user_ids).delete_all
      User.where(id: @user_ids).delete_all
    end

    test "duplicate direct redemption creates only one account and session" do
      record = prepare(email: "duplicate-confirmation@example.test")
      @pending_ids << record.id
      token = token_for(record)
      contender = nil
      winner = PendingRegistration.transaction do
        record.lock!
        contender = blocked_operation(-> { CompleteRegistration.call(token:) })
        CompleteRegistration.call(token:)
      end
      @user_ids << winner.user_id
      loser = Timeout.timeout(5) { contender.value }
      assert_instance_of RegistrationUnavailable, loser
      assert_equal 1, User.where(id: winner.user_id).count
      assert_equal 1, Session.where(user_id: winner.user_id).count
      assert_not PendingRegistration.exists?(record.id)
    end

    test "committed guest replacement wins over waiting confirmation" do
      guest = GuestUser.create!
      @user_ids << guest.id
      original = prepare(email: "replacement-confirmation@example.test", guest:)
      @pending_ids << original.id
      token = token_for(original)
      contender = nil
      replacement = PendingRegistration.transaction do
        guest.lock!
        contender = blocked_operation(-> { CompleteRegistration.call(token:) })
        prepare(email: "replacement-confirmation@example.test", guest:)
      end
      @pending_ids << replacement.id
      loser = Timeout.timeout(5) { contender.value }
      assert_instance_of RegistrationUnavailable, loser
      assert_instance_of GuestUser, User.find(guest.id)
      assert PendingRegistration.exists?(replacement.id)
      assert_not Session.exists?(user_id: guest.id)
    end

    test "guest confirmation prevents a waiting preparation from recreating pending credentials" do
      guest = GuestUser.create!
      @user_ids << guest.id
      record = prepare(email: "confirmation-wins@example.test", guest:)
      @pending_ids << record.id
      token = token_for(record)
      contender = nil
      session = PendingRegistration.transaction do
        guest.lock!
        contender = blocked_operation(-> { prepare(email: "confirmation-wins@example.test", guest:) })
        CompleteRegistration.call(token:)
      end
      assert_instance_of RegistrationUnavailable, Timeout.timeout(5) { contender.value }
      assert_instance_of RegisteredUser, User.find(guest.id)
      assert session.active?
      assert_not PendingRegistration.exists?(guest_user_id: guest.id)
    end

    test "waiting across the guest expiry deadline cannot complete registration" do
      freeze_time
      guest = GuestUser.create!
      @user_ids << guest.id
      record = prepare(email: "waiting-expiry@example.test", guest:)
      @pending_ids << record.id
      travel_to guest.created_at + 24.hours - 1.second
      token = token_for(record)
      contender = nil
      PendingRegistration.transaction do
        guest.lock!
        contender = blocked_operation(-> { CompleteRegistration.call(token:) })
        travel 2.seconds
      end
      assert_instance_of RegistrationUnavailable, Timeout.timeout(5) { contender.value }
      assert_instance_of GuestUser, User.find(guest.id)
      assert PendingRegistration.exists?(record.id)
      assert_not Session.exists?(user_id: guest.id)
    end

    test "two direct requests for one email cannot complete into duplicate accounts" do
      first = prepare(email: "email-race@example.test")
      second = prepare(email: "email-race@example.test")
      @pending_ids.concat [ first.id, second.id ]
      first_token = token_for(first)
      second_token = token_for(second)
      contender = nil
      winner = PendingRegistration.transaction do
        session = CompleteRegistration.call(token: first_token)
        @user_ids << session.user_id
        # The first account is not committed: the second passes model uniqueness
        # validation and must wait on PostgreSQL's unique index enforcement.
        contender = blocked_operation(-> { CompleteRegistration.call(token: second_token) })
        session
      end
      loser = Timeout.timeout(5) { contender.value }
      assert_instance_of RegistrationUnavailable, loser
      assert_nil loser.cause
      assert_equal 1, RegisteredUser.where(email_address: "email-race@example.test").count
      assert_equal 1, Session.where(user_id: winner.user_id).count
      assert PendingRegistration.exists?(second.id)
    end
  end
end
