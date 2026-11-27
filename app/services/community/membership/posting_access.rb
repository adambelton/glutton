module Community
  module Membership
    class PostingAccess
      def self.allowed?(user:)
        Access.allowed?(user:) && (user.community_user&.ready_to_post? || false)
      end
    end
  end
end
