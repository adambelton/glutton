module Community
  module Membership
    class ReadPublicProfile
      Page = Data.define(:community_user, :can_suspend, :can_block)

      def self.for_display(id:, viewer:)
        community_user = call(id:, viewer:)
        Page.new(community_user:,
          can_suspend: Suspension.can_start?(member: community_user.user, moderator: viewer),
          can_block: viewer.community_user&.can_block_member?(member: community_user) || false)
      end

      def self.call(id:, viewer:, lock: false)
        Access.require!(user: viewer)
        profiles = CommunityUser.all
        profiles = profiles.lock if lock
        profile = profiles.find(id)
        raise ActiveRecord::RecordNotFound unless profile.public_identity?

        MemberVisibility.require_visible!(viewer_id: viewer.id, blockable: profile)

        profile
      end
    end
  end
end
