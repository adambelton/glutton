module Community
  module Membership
    class PostingAccess
      def self.allowed?(user:)
        Access.allowed?(user:) &&
          CodeOfConduct.current.accepted_by?(member: user) &&
          user.community_username.present? && user.community_avatar_preset.present?
      end
    end
  end
end
