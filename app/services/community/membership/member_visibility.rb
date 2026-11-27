module Community
  module Membership
    class MemberVisibility
      def self.hidden?(viewer:, blockable:)
        profile = viewer&.community_user
        profile.present? && profile.member_hidden?(blockable&.member_id_for_blocking)
      end

      def self.require_visible!(viewer_id:, blockable:)
        MemberBlock.require_visible!(viewer_id:, member_id: blockable&.member_id_for_blocking)
      end
    end
  end
end
