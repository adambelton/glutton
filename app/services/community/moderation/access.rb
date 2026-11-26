module Community
  module Moderation
    class Access
      def self.manage_roles?(user:)
        Membership::Access.allowed?(user:) && user.superuser?
      end

      def self.review?(user:)
        Membership::Access.allowed?(user:) && ModeratorRole.active.exists?(member_id: user.id)
      end
    end
  end
end
