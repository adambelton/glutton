require "test_helper"
require "timeout"

module Identity
  class CompleteRegistrationConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    def prepare(email:, guest: nil)
      Registration::PrepareRegistration.call(email_address: email, guest_user_id: guest&.id,
        password: "a long password phrase", password_confirmation: "a long password phrase")
    end

    def token_for(record)
      Registration::RegistrationConfirmation.token_for(pending_registration_id: record.id)
    end

    def blocked_operation(operation)
      ready = Queue.new
      thread = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          ready << connection.select_value("SELECT pg_backend_pid()")
          begin
            operation.call
          rescue Errors::RegistrationUnavailable => error
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
      Identity::PendingRegistration.where(id: @pending_ids).delete_all
      Identity::Session.where(user_id: @user_ids).delete_all
      Identity::User.where(id: @user_ids).delete_all
    end

    test "duplicate direct redemption creates only one account and session" do
      record = prepare(email: "duplicate-confirmation@example.test")
      @pending_ids << record.id
      token = token_for(record)
      contender = nil
      winner = Identity::PendingRegistration.transaction do
        record.lock!
        contender = blocked_operation(-> { Registration::CompleteRegistration.call(token:) })
        Registration::CompleteRegistration.call(token:)
      end
      @user_ids << winner.user_id
      loser = Timeout.timeout(5) { contender.value }
      assert_instance_of Errors::RegistrationUnavailable, loser
      assert_equal 1, Identity::User.where(id: winner.user_id).count
      assert_equal 1, Identity::Session.where(user_id: winner.user_id).count
      assert_not Identity::PendingRegistration.exists?(record.id)
    end

    test "concurrent browser completion attaches once and issues one surviving session" do
      guest = Identity::UserGuest.create!
      @user_ids << guest.id
      record = prepare(email: "browser-confirmation-race@example.test")
      @pending_ids << record.id
      token = token_for(record)
      contender = nil
      operation = -> { Registration::CompleteBrowserRegistration.call(token:, current_user_id: guest.id) }
      winner = Identity::User.transaction do
        guest.lock!
        contender = blocked_operation(operation)
        operation.call
      end

      assert_instance_of Errors::RegistrationUnavailable, Timeout.timeout(5) { contender.value }
      assert_equal guest.id, winner.user_id
      assert winner.active?
      assert_equal [ winner.id ], Identity::Session.where(user_id: guest.id).pluck(:id)
      assert_not Identity::PendingRegistration.exists?(record.id)
    end

    test "different guests cannot both claim an unattached registration" do
      first_guest = Identity::UserGuest.create!
      second_guest = Identity::UserGuest.create!
      @user_ids.concat [ first_guest.id, second_guest.id ]
      record = prepare(email: "different-guests-confirmation@example.test")
      @pending_ids << record.id
      token = token_for(record)
      contender = nil
      winner = Identity::User.transaction do
        completed = Registration::CompleteBrowserRegistration.call(token:, current_user_id: first_guest.id)
        contender = blocked_operation(-> { Registration::CompleteBrowserRegistration.call(token:, current_user_id: second_guest.id) })
        completed
      end

      assert_instance_of Errors::RegistrationUnavailable, Timeout.timeout(5) { contender.value }
      assert_equal first_guest.id, winner.user_id
      assert winner.active?
      assert_not Identity::User.find(second_guest.id).can_reset_password?
      assert_not Identity::Session.exists?(user_id: second_guest.id)
      assert_not Identity::PendingRegistration.exists?(record.id)
    end

    test "committed guest replacement wins over waiting confirmation" do
      guest = Identity::UserGuest.create!
      @user_ids << guest.id
      original = prepare(email: "replacement-confirmation@example.test", guest:)
      @pending_ids << original.id
      token = token_for(original)
      contender = nil
      replacement = Identity::PendingRegistration.transaction do
        guest.lock!
        contender = blocked_operation(-> { Registration::CompleteRegistration.call(token:) })
        prepare(email: "replacement-confirmation@example.test", guest:)
      end
      @pending_ids << replacement.id
      loser = Timeout.timeout(5) { contender.value }
      assert_instance_of Errors::RegistrationUnavailable, loser
      assert_not (Identity::User.find(guest.id)).can_reset_password?
      assert Identity::PendingRegistration.exists?(replacement.id)
      assert_not Identity::Session.exists?(user_id: guest.id)
    end

    test "guest confirmation prevents a waiting preparation from recreating pending credentials" do
      guest = Identity::UserGuest.create!
      @user_ids << guest.id
      record = prepare(email: "confirmation-wins@example.test", guest:)
      @pending_ids << record.id
      token = token_for(record)
      contender = nil
      session = Identity::PendingRegistration.transaction do
        guest.lock!
        contender = blocked_operation(-> { prepare(email: "confirmation-wins@example.test", guest:) })
        Registration::CompleteRegistration.call(token:)
      end
      assert_instance_of Errors::RegistrationUnavailable, Timeout.timeout(5) { contender.value }
      assert (Identity::User.find(guest.id)).can_reset_password?
      assert session.active?
      assert_not Identity::PendingRegistration.exists?(guest_user_id: guest.id)
    end

    test "waiting across the guest expiry deadline cannot complete registration" do
      freeze_time
      guest = Identity::UserGuest.create!
      @user_ids << guest.id
      travel_to guest.created_at + Identity::UserGuest::EXPIRY_DURATION - 1.second
      record = prepare(email: "waiting-expiry@example.test", guest:)
      @pending_ids << record.id
      token = token_for(record)
      contender = nil
      Identity::PendingRegistration.transaction do
        guest.lock!
        contender = blocked_operation(-> { Registration::CompleteRegistration.call(token:) })
        travel 2.seconds
      end
      assert_instance_of Errors::RegistrationUnavailable, Timeout.timeout(5) { contender.value }
      assert_not (Identity::User.find(guest.id)).can_reset_password?
      assert Identity::PendingRegistration.exists?(record.id)
      assert_not Identity::Session.exists?(user_id: guest.id)
    end

    test "two direct requests for one email cannot complete into duplicate accounts" do
      first = prepare(email: "email-race@example.test")
      second = prepare(email: "email-race@example.test")
      @pending_ids.concat [ first.id, second.id ]
      first_token = token_for(first)
      second_token = token_for(second)
      contender = nil
      winner = Identity::PendingRegistration.transaction do
        session = Registration::CompleteRegistration.call(token: first_token)
        @user_ids << session.user_id
        # The first account is not committed: the second passes model uniqueness
        # validation and must wait on PostgreSQL's unique index enforcement.
        contender = blocked_operation(-> { Registration::CompleteRegistration.call(token: second_token) })
        session
      end
      loser = Timeout.timeout(5) { contender.value }
      assert_instance_of Errors::RegistrationUnavailable, loser
      assert_nil loser.cause
      assert_equal 1, Identity::UserRegistered.where(email_address: "email-race@example.test").count
      assert_equal 1, Identity::Session.where(user_id: winner.user_id).count
      assert Identity::PendingRegistration.exists?(second.id)
    end
  end
end
