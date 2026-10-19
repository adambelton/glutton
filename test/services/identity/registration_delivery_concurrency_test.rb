require "test_helper"
require "timeout"

module Identity
  class RegistrationDeliveryConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    Transport = Struct.new(:callback) do
      def deliver_now
        callback.call
      end
    end

    setup do
      @origin = ENV["APP_ORIGIN"]
      ENV["APP_ORIGIN"] = "https://glutton.example.test"
      @pending_ids = []
      @user_ids = []
      @threads = []
    end

    teardown do
      AccountMailer.singleton_class.remove_method(:confirmation) if AccountMailer.singleton_class.instance_methods(false).include?(:confirmation)
      @threads.each { |thread| thread.kill if thread.alive?; thread.join }
      PendingRegistration.where(id: @pending_ids).delete_all
      Session.where(user_id: @user_ids).delete_all
      User.where(id: @user_ids).delete_all
      ENV["APP_ORIGIN"] = @origin
    end

    def prepare(guest: nil)
      record = PrepareRegistration.call(guest_user_id: guest&.id, email_address: "delivery@example.test",
        password: "a long password phrase", password_confirmation: "a long password phrase")
      @pending_ids << record.id
      record
    end

    def blocked(&operation)
      ready = Queue.new
      thread = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          ready << connection.select_value("SELECT pg_backend_pid()")
          begin
            operation.call
          rescue RegistrationUnavailable, RegistrationConflict, DeliverRegistrationConfirmation::Limited => error
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

    test "simultaneous sends reserve once and perform transport only after commit" do
      deliveries = Queue.new
      AccountMailer.define_singleton_method(:confirmation) do |**arguments|
        Transport.new(-> { raise "transport inside transaction" if ActiveRecord::Base.connection.transaction_open?; deliveries << arguments; :sent })
      end
      record = prepare
      contenders = PendingRegistration.transaction do
        record.lock!
        2.times.map { blocked { DeliverRegistrationConfirmation.call(pending_registration_id: record.id) } }
      end
      results = contenders.map { |thread| Timeout.timeout(5) { thread.value } }
      assert_equal 1, results.count(:sent)
      assert_equal 1, results.count { |result| result.is_a?(DeliverRegistrationConfirmation::Limited) }
      assert_equal 1, deliveries.size
      assert_equal "delivery@example.test", deliveries.pop[:recipient]
      assert_equal 1, record.reload.confirmation_delivery_attempts
    end

    test "known transport failure consumes one committed attempt and hides provider detail" do
      AccountMailer.define_singleton_method(:confirmation) do |**|
        Transport.new(-> { raise "transport inside transaction" if ActiveRecord::Base.connection.transaction_open?; raise Net::SMTPFatalError, "private-provider-marker" })
      end
      record = prepare
      error = assert_raises(DeliverRegistrationConfirmation::Failed) { DeliverRegistrationConfirmation.call(pending_registration_id: record.id) }
      assert_nil error.cause
      refute_includes error.full_message, "private-provider-marker"
      assert_equal 1, record.reload.confirmation_delivery_attempts
      assert_equal 0, User.count
    end

    test "unexpected transport programming failure propagates" do
      AccountMailer.define_singleton_method(:confirmation) { |**| Transport.new(-> { raise TypeError, "unexpected" }) }
      record = prepare
      assert_raises(TypeError) { DeliverRegistrationConfirmation.call(pending_registration_id: record.id) }
      assert_equal 1, record.reload.confirmation_delivery_attempts
    end

    test "attachment waiting behind replacement rejects the old request" do
      guest = GuestUser.create!
      @user_ids << guest.id
      record = prepare(guest:)
      contender = nil
      replacement = PendingRegistration.transaction do
        guest.lock!
        contender = blocked { AttachRegistration.call(pending_registration_id: record.id, guest_user_id: guest.id) }
        prepare(guest:)
      end
      result = Timeout.timeout(5) { contender.value }
      assert_instance_of RegistrationUnavailable, result
      assert_equal guest.id, replacement.reload.guest_user_id
      assert_not PendingRegistration.exists?(record.id)
    end

    test "attachment after committed confirmation cannot resurrect pending credentials" do
      record = prepare
      guest = GuestUser.create!
      @user_ids << guest.id
      token = RegistrationConfirmation.token_for(pending_registration_id: record.id)
      contender = nil
      new_session = PendingRegistration.transaction do
        record.lock!
        contender = blocked { AttachRegistration.call(pending_registration_id: record.id, guest_user_id: guest.id) }
        CompleteRegistration.call(token:)
      end
      @user_ids << new_session.user_id
      result = Timeout.timeout(5) { contender.value }
      assert_instance_of RegistrationUnavailable, result
      assert_not PendingRegistration.exists?(record.id)
      assert_instance_of GuestUser, User.find(guest.id)
      assert new_session.active?
    end
  end
end
