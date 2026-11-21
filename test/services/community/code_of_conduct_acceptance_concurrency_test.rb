require "test_helper"
require "timeout"

module Community
  class CodeOfConductAcceptanceConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      password = "a long test password"
      @member = Identity::UserRegistered.create!(email_address: "conduct-concurrency@example.test", password:,
        password_confirmation: password, email_confirmed_at: Time.current)
    end

    teardown do
      @contender&.kill if @contender&.alive?
      @contender&.join
      @member.destroy!
    end

    test "concurrent and later acceptance preserve the original receipt" do
      backend_pid = Queue.new
      original = Identity::UserRegistered.transaction do
        receipt = accept_current_version
        @contender = Thread.new do
          Identity::UserRegistered.with_connection do |connection|
            backend_pid << connection.select_value("SELECT pg_backend_pid()")
            accept_current_version
          end
        end
        pid = Timeout.timeout(5) { backend_pid.pop }
        Identity::UserRegistered.with_connection do |connection|
          Timeout.timeout(5) do
            until connection.uncached { connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)}))") }.positive?
              sleep 0.01
            end
          end
        end
        receipt
      end

      repeated = Timeout.timeout(5) { @contender.value }
      assert_equal original.id, repeated.id
      travel 1.hour do
        assert_equal original.accepted_at, accept_current_version.accepted_at
      end
      assert_equal 1, CodeOfConductAcceptance.where(user: @member).count
    end

    private

    def accept_current_version
      AcceptCodeOfConduct.call(user_id: @member.id, displayed_version: CodeOfConduct.current.version, accepted: true)
    end
  end
end
