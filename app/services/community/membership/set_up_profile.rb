module Community
  module Membership
    class SetUpProfile
      def self.call(user_id:, displayed_version:, accepted:)
        CommunityUser.transaction do
          user = Identity::AccountAdministration::ManageRegisteredAccount.new(user_id:).record_community_code_of_conduct_acceptance do
            CodeOfConduct.current.version_for_acceptance!(displayed_version:, accepted:)
          end
          CommunityUser.provision_for!(user:)
          user
        end
      rescue Identity::Errors::Unavailable
        raise Errors::MembershipRequired
      end
    end
  end
end
