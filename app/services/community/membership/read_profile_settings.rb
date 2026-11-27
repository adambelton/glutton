module Community
  module Membership
    class ReadProfileSettings
      Page = Data.define(:community_user, :blocks, :suspended, :code, :accepted)

      def self.call(viewer:)
        community_user = viewer.community_user
        code = CodeOfConduct.current
        Page.new(community_user:, blocks: BrowseMemberBlocks.call(community_user:),
          suspended: Access.suspended?(user: viewer), code:, accepted: code.accepted_by?(user: viewer))
      end
    end
  end
end
