module Community
  module Membership
    class BrowseMemberBlocks
      def self.call(community_user:)
        return [] unless community_user.present?

        community_user.outgoing_blocks.preload(:blocked).order(:id).to_a
      end
    end
  end
end
