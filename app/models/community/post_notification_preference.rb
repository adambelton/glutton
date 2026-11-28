module Community
  class PostNotificationPreference < ApplicationRecord
    self.table_name = "community_post_notification_preferences"

    MODES = %w[follow mute].freeze

    belongs_to :user, class_name: "Identity::UserRegistered"
    belongs_to :post, class_name: "Community::Post"
    belongs_to :film, class_name: "Registry::Film", optional: true

    validates :mode, inclusion: { in: MODES }

    def change_mode!(mode:)
      update!(mode:)
    end

    def following?
      mode == "follow"
    end
  end
end
