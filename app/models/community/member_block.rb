module Community
  class MemberBlock < ApplicationRecord
    self.table_name = "community_member_blocks"

    belongs_to :blocker, class_name: "Community::CommunityUser"
    belongs_to :blocked, class_name: "Community::CommunityUser"

    def self.require_visible!(viewer_id:, member_id:)
      return if member_id.nil? || viewer_id == member_id

      if where(blocker_id: viewer_id, blocked_id: member_id).or(where(blocker_id: member_id, blocked_id: viewer_id)).exists?
        raise ActiveRecord::RecordNotFound
      end
    end

    def self.hidden_ids_for(member_id)
      where(blocker_id: member_id).or(where(blocked_id: member_id))
        .pluck(:blocker_id, :blocked_id).map { |blocker_id, blocked_id| blocker_id == member_id ? blocked_id : blocker_id }.to_set
    end
  end
end
