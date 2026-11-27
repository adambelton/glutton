require "test_helper"
require "timeout"

module Community
  module Membership
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

      test "concurrent and later acceptance preserve the original timestamp" do
        backend_pid = Queue.new
        original = Identity::UserRegistered.transaction do
          accepted_member = accept_current_version
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
          accepted_member
        end

        repeated = Timeout.timeout(5) { @contender.value }
        assert_equal original.community_code_of_conduct_accepted_at, repeated.community_code_of_conduct_accepted_at
        travel 1.hour do
          assert_equal original.community_code_of_conduct_accepted_at, accept_current_version.community_code_of_conduct_accepted_at
        end
        assert_equal CodeOfConduct.current.version, @member.reload.community_code_of_conduct_version
      end

      private

      def accept_current_version
        SetUpProfile.call(user_id: @member.id, displayed_version: CodeOfConduct.current.version, accepted: true)
      end
    end
  end
end
