require "test_helper"

module Community
  module Membership
    class ManageProfileTest < ActiveSupport::TestCase
      test "profile settings reject a retained profile after account closure" do
        password = "a long test password"
        user = create_community_account(email_address: "closed-profile@example.test", password:, password_confirmation: password,
          email_confirmed_at: Time.current, community_code_of_conduct_version: CodeOfConduct.current.version,
          community_code_of_conduct_accepted_at: Time.current)
        settings = ManageProfile.new(community_user: user.community_user)

        client = Aws::S3::Client.new(region: "auto", stub_responses: true)
        log = Identity::AccountAdministration::DeletionLog.new(client:, bucket: "fixture", namespace: "recovery")
        Identity::AccountAdministration::ManageRegisteredAccount.new(user_id: user.id).close_account(deletion_log: log)

        assert_raises(Errors::MembershipRequired) do
          settings.change_community_username(community_username: "Closed_Account")
        end
        assert_not CommunityUser.exists?(user.id)
      end
    end
  end
end
