require "test_helper"
require "timeout"

module Identity
  class PasswordRecoveryConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      @user = UserRegistered.create!(email_address: "recovery-concurrency@example.test", password: "original password phrase",
        password_confirmation: "original password phrase", email_confirmed_at: Time.current)
    end

    teardown do
      @thread&.kill if @thread&.alive?
      @thread&.join
      Session.where(user_id: @user.id).delete_all
      @user.delete
    end

    test "waiting duplicate redemption revalidates digest after locking" do
      token = @user.password_reset_token
      ready = Queue.new
      UserRegistered.transaction do
        @user.lock!
        @thread = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()")
            begin
              ResetPassword.call(token:, password: "losing password phrase", password_confirmation: "losing password phrase")
            rescue PasswordResetUnavailable => error
              error
            end
          end
        end
        pid = Timeout.timeout(5) { ready.pop }
        connection = ActiveRecord::Base.connection
        Timeout.timeout(5) do
          until connection.uncached { connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)}))") }.positive?
            sleep 0.01
          end
        end
        ResetPassword.call(token:, password: "winning password phrase", password_confirmation: "winning password phrase")
      end
      assert_instance_of PasswordResetUnavailable, Timeout.timeout(5) { @thread.value }
      assert @user.reload.authenticate("winning password phrase")
      assert_not @user.authenticate("losing password phrase")
    end

    test "reset committed before waiting sign-in rejects the old password" do
      token = @user.password_reset_token
      contender = nil
      UserRegistered.transaction do
        @user.lock!
        contender = blocked_operation do
          Authenticate.call(email_address: @user.email_address, password: "original password phrase")
        end
        ResetPassword.call(token:, password: "replacement password phrase", password_confirmation: "replacement password phrase")
      end

      assert_nil Timeout.timeout(5) { contender.value }
      assert_not Session.exists?(user_id: @user.id)
      assert Authenticate.call(email_address: @user.email_address, password: "replacement password phrase").active?
    end

    test "reset waiting for a successful sign-in revokes the issued session" do
      token = @user.password_reset_token
      contender = nil
      authentication = UserRegistered.transaction do
        session = Authenticate.call(email_address: @user.email_address, password: "original password phrase")
        contender = blocked_operation do
          ResetPassword.call(token:, password: "replacement password phrase", password_confirmation: "replacement password phrase")
        end
        session
      end

      Timeout.timeout(5) { contender.value }
      assert_not authentication.active?
      assert_not Session.exists?(user_id: @user.id)
      assert_nil Authenticate.call(email_address: @user.email_address, password: "original password phrase")
    end

    test "mail transport runs with no open transaction or account row lock" do
      origin = ENV["APP_ORIGIN"]
      ENV["APP_ORIGIN"] = "https://glutton.example.test"
      original = AccountMailer.method(:password_reset)
      observed = false
      user_id = @user.id
      delivery = Object.new
      delivery.define_singleton_method(:deliver_now) do
        raise "SMTP inside transaction" if ActiveRecord::Base.connection.transaction_open?
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            UserRegistered.transaction do
              UserRegistered.lock("FOR UPDATE NOWAIT").find(user_id)
            end
          end
        end.value
        observed = true
      end
      AccountMailer.define_singleton_method(:password_reset) { |**| delivery }
      RequestPasswordReset.call(email_address: @user.email_address)
      assert observed
    ensure
      ENV["APP_ORIGIN"] = origin
      AccountMailer.define_singleton_method(:password_reset, original) if original
    end

    private

    def blocked_operation(&operation)
      ready = Queue.new
      @thread = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          ready << connection.select_value("SELECT pg_backend_pid()")
          operation.call
        end
      end
      pid = Timeout.timeout(5) { ready.pop }
      connection = ActiveRecord::Base.connection
      Timeout.timeout(5) do
        until connection.uncached { connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)}))") }.positive?
          sleep 0.01
        end
      end
      @thread
    end
  end
end
