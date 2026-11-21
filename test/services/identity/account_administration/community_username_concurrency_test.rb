require "test_helper"
require "timeout"

module Identity
  class CommunityUsernameConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      password = "a long test password"
      @accounts = %w[first second].map do |member|
        UserRegistered.create!(email_address: "username-#{member}@example.test", password:,
          password_confirmation: password, email_confirmed_at: Time.current)
      end
    end

    teardown do
      @contender&.kill if @contender&.alive?
      @contender&.join
      @accounts.each(&:destroy!)
    end

    test "concurrent case variants produce one claim and a recoverable conflict" do
      winner, contender = @accounts
      first_settings = AccountAdministration::ManageRegisteredAccount.new(user_id: winner.id)
      second_settings = AccountAdministration::ManageRegisteredAccount.new(user_id: contender.id)
      backend_pid = Queue.new

      UserRegistered.transaction do
        first_settings.change_community_username(community_username: "Night_Owl")
        @contender = Thread.new do
          UserRegistered.with_connection do |connection|
            backend_pid << connection.select_value("SELECT pg_backend_pid()")
            second_settings.change_community_username(community_username: "night_owl")
          rescue ActiveRecord::RecordInvalid => error
            error.record.errors.of_kind?(:community_username, :taken)
          end
        end
        pid = Timeout.timeout(5) { backend_pid.pop }
        UserRegistered.with_connection do |connection|
          Timeout.timeout(5) do
            until connection.uncached { connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)}))") }.positive?
              sleep 0.01
            end
          end
        end
      end

      assert_equal true, Timeout.timeout(5) { @contender.value }
      assert_equal "Night_Owl", winner.reload.community_username
      assert_nil contender.reload.community_username
      second_settings.change_community_username(community_username: "Other_Owl")
      assert_equal "Other_Owl", contender.reload.community_username
    end
  end
end
