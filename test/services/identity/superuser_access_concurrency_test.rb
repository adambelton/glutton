require "test_helper"
require "timeout"

module Identity
  class SuperuserAccessConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      @actor = UserRegistered.create!(email_address: "operator-concurrency@example.test", password: "a long password phrase",
        password_confirmation: "a long password phrase", email_confirmed_at: Time.current, superuser: true)
      @user = UserRegistered.create!(email_address: "admin-concurrency@example.test", password: "a long password phrase",
        password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    end

    teardown do
      @thread&.kill if @thread&.alive?
      @thread&.join
      @other_thread&.kill if @other_thread&.alive?
      @other_thread&.join
      @user.delete
      @actor.delete
    end

    test "concurrent duplicate grants and revocations have one explicit winner" do
      [ [ GrantSuperuser, SuperuserAlreadyGranted ], [ RevokeSuperuser, SuperuserAlreadyRevoked ] ].each do |operation, failure|
        contender = nil
        User.transaction do
          @actor.lock!
          @user.lock!
          contender = blocked_operation do
            operation.call(user_id: @user.id, actor_user_id: @actor.id)
          rescue failure => error
            error
          end
          operation.call(user_id: @user.id, actor_user_id: @actor.id)
        end
        assert_instance_of failure, Timeout.timeout(5) { contender.value }
      end
      assert_not @user.reload.superuser?
    end

    test "waiting revocation re-reads permission after a concurrent grant" do
      contender = nil
      User.transaction do
        @actor.lock!
        @user.lock!
        contender = blocked_operation { RevokeSuperuser.call(user_id: @user.id, actor_user_id: @actor.id) }
        GrantSuperuser.call(user_id: @user.id, actor_user_id: @actor.id)
      end
      assert_not Timeout.timeout(5) { contender.value }.superuser?
      assert_not @user.reload.superuser?
    end

    test "waiting grant rejects a concurrently removed account" do
      contender = nil
      User.transaction do
        @actor.lock!
        @user.lock!
        contender = blocked_operation do
          GrantSuperuser.call(user_id: @user.id, actor_user_id: @actor.id)
        rescue SuperuserUnavailable => error
          error
        end
        @user.destroy!
      end
      assert_instance_of SuperuserUnavailable, Timeout.timeout(5) { contender.value }
    end

    test "an actor revoked while a grant waits cannot authorize that grant" do
      contender = nil
      User.transaction do
        @actor.lock!
        contender = blocked_operation do
          GrantSuperuser.call(user_id: @user.id, actor_user_id: @actor.id)
        rescue SuperuserRequired => error
          error
        end
        @actor.revoke_superuser!(actor: @actor)
      end
      assert_instance_of SuperuserRequired, Timeout.timeout(5) { contender.value }
      assert_not @user.reload.superuser?
    end

    test "opposing revocations serialize without deadlocking and reject the revoked actor" do
      GrantSuperuser.call(user_id: @user.id, actor_user_id: @actor.id)
      ready = Queue.new
      start = Queue.new
      operation = ->(actor_id, target_id) do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ready << true
            start.pop
            begin
              RevokeSuperuser.call(user_id: target_id, actor_user_id: actor_id)
              :revoked
            rescue SuperuserRequired
              :unauthorized
            end
          end
        end
      end
      @thread = operation.call(@actor.id, @user.id)
      @other_thread = operation.call(@user.id, @actor.id)
      Timeout.timeout(5) { 2.times { ready.pop } }
      2.times { start << true }
      results = Timeout.timeout(5) { [ @thread.value, @other_thread.value ] }
      assert_equal [ :revoked, :unauthorized ], results.sort
      assert_equal 1, [ @actor.reload, @user.reload ].count(&:superuser?)
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
