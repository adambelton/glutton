module Community
  class Notification < ApplicationRecord
    self.table_name = "community_notifications"

    belongs_to :recipient, class_name: "Identity::UserRegistered"
    belongs_to :comment_content

    scope :unread, -> { where(read_at: nil) }

    def self.record_comment!(recipient:, content:)
      create_or_find_by!(recipient:, comment_content: content)
    end

    def mark_read!
      with_lock { update!(read_at: Time.current) if read_at.nil? }
    end
  end
end
