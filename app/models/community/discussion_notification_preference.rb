module Community
  class DiscussionNotificationPreference < ApplicationRecord
    self.table_name = "community_discussion_notification_preferences"

    belongs_to :user, class_name: "Identity::UserRegistered"

    def change_direct_replies!(enabled:)
      self.direct_replies = enabled
      save! if will_save_change_to_direct_replies?
    end
  end
end
