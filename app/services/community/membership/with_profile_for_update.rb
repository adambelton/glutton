module Community
  module Membership
    class WithProfileForUpdate
      def self.call(community_user:)
        CommunityUser.transaction do
          # Account closure and Library updates also take the account lock first.
          user = Identity::UserRegistered.lock.find_by(id: community_user.user_id) if community_user.present?
          yield user&.community_user
        end
      end
    end
  end
end
