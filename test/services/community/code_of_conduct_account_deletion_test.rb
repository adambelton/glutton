require "test_helper"

module Community
  class CodeOfConductAccountDeletionTest < ActiveSupport::TestCase
    setup do
      password = "a long test password"
      @member = Identity::UserRegistered.create!(email_address: "conduct-delete@example.test", password:,
        password_confirmation: password, email_confirmed_at: Time.current)
      AcceptCodeOfConduct.call(user_id: @member.id, displayed_version: CodeOfConduct.current.version, accepted: true)
    end

    test "account closure cascades to Community acceptances" do
      client = Aws::S3::Client.new(region: "auto", stub_responses: true)
      deletion_log = Identity::AccountAdministration::DeletionLog.new(client:, bucket: "fixture", namespace: "recovery")

      assert_difference -> { CodeOfConductAcceptance.where(user_id: @member.id).count }, -1 do
        Identity::AccountAdministration::ManageRegisteredAccount.new(user_id: @member.id).close_account(deletion_log:)
      end
    end

    test "backup deletion replay cascades to Community acceptances" do
      deletion_log = Struct.new(:account_ids).new([ @member.deletion_replay_id ])

      assert_difference -> { CodeOfConductAcceptance.where(user_id: @member.id).count }, -1 do
        assert_equal 1, Identity::AccountAdministration::ReplayAccountDeletions.new(deletion_log:).call
      end
    end
  end
end
